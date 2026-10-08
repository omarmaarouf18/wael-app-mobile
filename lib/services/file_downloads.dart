import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/api_client.dart';
import '../models/academy_catalog.dart';

/// Fetches one subject PDF: `GET /api/v1/academy/subjects/{id}/files/
/// {fileId}/download` (SPEC Section 6). Completing `abort` cancels it.
typedef PdfFetcher =
    Future<DownloadResponse> Function(
      String subjectId,
      String fileId,
      Future<void> abort,
    );

/// [PdfFetcher] over the authed gateway client (401 refresh, error codes).
PdfFetcher httpPdfFetcher(ApiClient api) =>
    (subjectId, fileId, abort) => api.download(
      '/api/v1/academy/subjects/${Uri.encodeComponent(subjectId)}'
      '/files/${Uri.encodeComponent(fileId)}/download',
      abortTrigger: abort,
    );

/// Why a download did not produce a usable PDF (besides an [ApiException]
/// from the server or a network error).
enum DownloadFailure {
  /// The body did not start with `%PDF-`.
  notPdf,

  /// The body ended before `Content-Length` bytes arrived.
  incomplete,

  /// The body passed [FileDownloadStore.maxBytes].
  tooLarge,

  /// Writing to the app-private cache failed (disk full, removed).
  storage,

  /// The ids are not safe to use as directory names.
  invalidId,
}

class DownloadException implements Exception {
  DownloadException(this.failure);

  final DownloadFailure failure;

  @override
  String toString() => 'DownloadException(${failure.name})';
}

/// Thrown into the download when the student cancels it.
class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

/// A PDF kept in the app-private cache, with what the notes tab needs to
/// list it offline (no network, no subject detail).
class DownloadedFile {
  const DownloadedFile({
    required this.fileId,
    required this.subjectId,
    required this.subjectTitle,
    required this.title,
    required this.kind,
    required this.sizeBytes,
    required this.path,
  });

  final String fileId;
  final String subjectId;
  final LocalizedText subjectTitle;
  final LocalizedText title;
  final String kind;
  final int sizeBytes;

  /// Absolute path of the PDF inside the cache root.
  final String path;

  AcademyFile get asFile =>
      AcademyFile(id: fileId, kind: kind, title: title, sizeBytes: sizeBytes);

  Map<String, dynamic> _toJson(String root) => {
    'subject_id': subjectId,
    'subject_title': subjectTitle.toJson(),
    'title': title.toJson(),
    'kind': kind,
    'size_bytes': sizeBytes,
    // Stored relative so the index survives a moved cache root.
    'path': path.substring(root.length + 1),
  };

  static DownloadedFile? _fromJson(String fileId, Object? json, String root) {
    if (json is! Map<String, dynamic>) return null;
    try {
      final rel = json['path'];
      final subjectId = json['subject_id'];
      if (rel is! String || subjectId is! String) return null;
      if (!FileDownloadStore.isSafeId(subjectId)) return null;
      if (rel.contains('..') || rel.startsWith('/')) return null;
      return DownloadedFile(
        fileId: fileId,
        subjectId: subjectId,
        subjectTitle: LocalizedText.fromJson(json['subject_title']),
        title: LocalizedText.fromJson(json['title']),
        kind: (json['kind'] ?? '').toString(),
        sizeBytes: json['size_bytes'] is int ? json['size_bytes'] as int : 0,
        path: '$root/$rel',
      );
    } catch (_) {
      return null;
    }
  }
}

/// Subject PDFs in the app-private cache directory (`<cache>/pdfs`), the
/// only place the Android FileProvider exposes (`res/xml/file_paths.xml`).
/// No storage permission is involved.
///
/// Layout: `pdfs/<subjectId>/<fileId>/<title>.pdf` plus `pdfs/index.json`,
/// which records the owner (the signed-in user id) and each file's titles so
/// the notes tab can list downloads offline. A different owner wipes the
/// folder (account switch). A download is written to a `.part` file and
/// renamed only when it is a complete PDF, so a half file is never opened.
class FileDownloadStore {
  FileDownloadStore({
    required Future<Directory> Function() cacheRoot,
    required PdfFetcher fetcher,
    this.bodyIdleTimeout = const Duration(seconds: 30),
  }) : _cacheRoot = cacheRoot, // ignore: prefer_initializing_formals
       _fetch = fetcher;

  final Future<Directory> Function() _cacheRoot;
  final PdfFetcher _fetch;

  /// A body that sends nothing for this long fails as a network error.
  final Duration bodyIdleTimeout;

  /// Client-side ceiling for one PDF (the server limit is `MAX_PDF_BYTES`,
  /// 20 MB by default, SPEC D14): a misbehaving answer cannot fill the disk.
  static const maxBytes = 64 * 1024 * 1024;

  static final _safeId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// Server ids become directory names; anything else is refused.
  static bool isSafeId(String id) => _safeId.hasMatch(id);

  Directory? _root;
  String _owner = '';
  final Map<String, DownloadedFile> _files = {};
  bool _loaded = false;

  Future<Directory> _dir() async {
    final cached = _root;
    if (cached != null) return cached;
    final base = await _cacheRoot();
    final dir = Directory('${base.path}/pdfs');
    _root = dir;
    return dir;
  }

  File _indexFile(Directory root) => File('${root.path}/index.json');

  /// Loads the index. [ownerId] is the signed-in user id, or null while it
  /// is unknown (an offline start before `/auth/me` answered): the existing
  /// copies are then kept as they are, since sign-out always wipes them. A
  /// known id that differs from the index owner wipes every cached PDF
  /// first (account switch); a broken index wipes too. Entries whose file
  /// is gone are dropped.
  Future<void> open(String? ownerId) async {
    final root = await _dir();
    _files.clear();
    Map<String, dynamic>? index;
    try {
      final raw = await _indexFile(root).readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) index = decoded;
    } catch (_) {
      index = null;
    }
    final stored = index?['owner'] is String ? index!['owner'] as String : '';
    final mismatch = ownerId != null && stored.isNotEmpty && stored != ownerId;
    if (index == null || mismatch) {
      await _wipe(root);
      _owner = ownerId ?? '';
      _loaded = true;
      await _save();
      return;
    }
    _owner = ownerId ?? stored;
    final entries = index['files'];
    if (entries is Map<String, dynamic>) {
      for (final e in entries.entries) {
        if (!isSafeId(e.key)) continue;
        final f = DownloadedFile._fromJson(e.key, e.value, root.path);
        if (f != null && await File(f.path).exists()) _files[e.key] = f;
      }
    }
    _loaded = true;
    await _save();
  }

  /// The user id the index belongs to ('' while unknown).
  String get owner => _owner;

  bool get isOpen => _loaded;

  /// Downloaded copies, in index order.
  List<DownloadedFile> get files => List.unmodifiable(_files.values);

  DownloadedFile? fileOf(String fileId) => _files[fileId];

  Future<void> _save() async {
    if (!_loaded) return;
    final root = await _dir();
    try {
      await root.create(recursive: true);
      final tmp = File('${root.path}/index.json.tmp');
      await tmp.writeAsString(
        jsonEncode({
          'owner': _owner,
          'files': {
            for (final f in _files.values) f.fileId: f._toJson(root.path),
          },
        }),
        flush: true,
      );
      await tmp.rename(_indexFile(root).path);
    } catch (_) {
      // Best effort: a lost index only means a re-download.
    }
  }

  Future<void> _wipe(Directory root) async {
    try {
      if (await root.exists()) await root.delete(recursive: true);
    } catch (_) {
      // Best effort.
    }
  }

  /// Downloads [file] of [subject] into the cache and returns the copy.
  /// [onProgress] gets (received, total); total is 0 when unknown. Throws
  /// [ApiException] for server refusals, [DownloadException] for a bad body
  /// or storage error, [DownloadCancelled] when [cancel] completes first,
  /// and the network error otherwise. Nothing is left behind on failure.
  Future<DownloadedFile> download({
    required AcademySubject subject,
    required AcademyFile file,
    required Future<void> cancel,
    void Function(int received, int total)? onProgress,
  }) async {
    if (!isSafeId(subject.id) || !isSafeId(file.id)) {
      throw DownloadException(DownloadFailure.invalidId);
    }
    final root = await _dir();
    final dir = Directory('${root.path}/${subject.id}/${file.id}');
    final part = File('${root.path}/${subject.id}/${file.id}.part');
    var cancelled = false;
    final abort = cancel.then((_) => cancelled = true);
    IOSink? sink;
    try {
      final res = await _fetch(subject.id, file.id, abort);
      if (cancelled) throw const DownloadCancelled();
      final declared = res.contentLength;
      if (declared != null && declared > maxBytes) {
        throw DownloadException(DownloadFailure.tooLarge);
      }
      final total = declared ?? (file.sizeBytes > 0 ? file.sizeBytes : 0);
      try {
        await part.parent.create(recursive: true);
        sink = part.openWrite();
      } on FileSystemException {
        throw DownloadException(DownloadFailure.storage);
      }
      var received = 0;
      final head = <int>[];
      onProgress?.call(0, total);
      await for (final chunk in res.stream.timeout(bodyIdleTimeout)) {
        if (cancelled) throw const DownloadCancelled();
        received += chunk.length;
        if (received > maxBytes) {
          throw DownloadException(DownloadFailure.tooLarge);
        }
        if (head.length < 5) {
          head.addAll(chunk.take(5 - head.length));
          if (head.length == 5 && !_isPdfMagic(head)) {
            throw DownloadException(DownloadFailure.notPdf);
          }
        }
        try {
          sink.add(chunk);
        } on FileSystemException {
          throw DownloadException(DownloadFailure.storage);
        }
        onProgress?.call(received, total < received ? received : total);
      }
      if (cancelled) throw const DownloadCancelled();
      if (head.length < 5 || !_isPdfMagic(head)) {
        throw DownloadException(DownloadFailure.notPdf);
      }
      if (declared != null && received != declared) {
        throw DownloadException(DownloadFailure.incomplete);
      }
      try {
        await sink.flush();
        await sink.close();
        sink = null;
        if (await dir.exists()) await dir.delete(recursive: true);
        await dir.create(recursive: true);
        final target = File('${dir.path}/${safePdfName(file.title)}');
        await part.rename(target.path);
        final saved = DownloadedFile(
          fileId: file.id,
          subjectId: subject.id,
          subjectTitle: subject.title,
          title: file.title,
          kind: file.kind,
          sizeBytes: received,
          path: target.path,
        );
        _files[file.id] = saved;
        await _save();
        return saved;
      } on FileSystemException {
        throw DownloadException(DownloadFailure.storage);
      }
    } on Object catch (e) {
      // An abort surfaces from http as a ClientException: report the
      // student's cancel, not a network error.
      if (cancelled && e is! DownloadCancelled) throw const DownloadCancelled();
      rethrow;
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      try {
        if (await part.exists()) await part.delete();
      } catch (_) {}
    }
  }

  static bool _isPdfMagic(List<int> head) =>
      head[0] == 0x25 && // %
      head[1] == 0x50 && // P
      head[2] == 0x44 && // D
      head[3] == 0x46 && // F
      head[4] == 0x2D; // -

  /// Whether [f]'s PDF is still on disk (the system may clear the cache).
  Future<bool> exists(DownloadedFile f) async {
    try {
      return await File(f.path).exists();
    } catch (_) {
      return false;
    }
  }

  /// Removes one cached copy (best effort).
  Future<void> remove(String fileId) async {
    final f = _files.remove(fileId);
    if (f == null) return;
    try {
      await File(f.path).parent.delete(recursive: true);
    } catch (_) {}
    await _save();
  }

  /// Removes every cached copy of [subjectId] (best effort).
  Future<void> removeSubject(String subjectId) async {
    if (!isSafeId(subjectId)) return;
    _files.removeWhere((_, f) => f.subjectId == subjectId);
    final root = await _dir();
    try {
      final d = Directory('${root.path}/$subjectId');
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
    await _save();
  }

  /// Fresh subject detail from the server: drops every copy of a subject
  /// that is no longer owned, and copies whose file left the subject.
  Future<void> reconcile(AcademySubjectDetail detail) async {
    if (!detail.owned) {
      if (_files.values.any((f) => f.subjectId == detail.id)) {
        await removeSubject(detail.id);
      }
      return;
    }
    final keep = {for (final f in detail.files) f.id};
    final gone = [
      for (final f in _files.values)
        if (f.subjectId == detail.id && !keep.contains(f.fileId)) f.fileId,
    ];
    for (final id in gone) {
      await remove(id);
    }
  }

  /// Deletes every cached PDF and the index (sign-out, account switch).
  Future<void> clearAll() async {
    _files.clear();
    _owner = '';
    _loaded = false;
    await _wipe(await _dir());
  }
}

/// File name for a cached PDF from its title: path separators, reserved and
/// control characters become `_`, whitespace collapses, at most 80
/// characters; an empty result is `document`. The name is what a receiving
/// app shows after Share.
String safePdfName(LocalizedText title) {
  final raw = title.ar.isNotEmpty ? title.ar : title.en;
  final cleaned = raw
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[\x00-\x1F\x7F/\\:*?"<>|]'), '_')
      .trim();
  var name = cleaned.replaceAll(RegExp(r'^\.+'), '');
  final runes = name.runes.toList();
  if (runes.length > 80) name = String.fromCharCodes(runes.take(80)).trim();
  if (name.isEmpty) name = 'document';
  return '$name.pdf';
}
