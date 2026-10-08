import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:wael_app/models/academy_catalog.dart';
import 'package:wael_app/services/file_downloads.dart';
import 'package:wael_app/services/file_opener.dart';

/// In-memory [FileDownloadStore] for widget tests: no file IO. Each
/// download waits for [gate] when set (progress via [progress]), then
/// throws [error] or saves the file.
class FakeFileDownloadStore implements FileDownloadStore {
  final Map<String, DownloadedFile> _files = {};
  final Set<String> missing = {};
  Object? error;
  Completer<void>? gate;
  void Function(int received, int total)? progress;
  final downloads = <String>[];
  String _owner = '';
  bool _open = false;

  /// Adds an already-downloaded copy (as found in the index at start).
  void seed(AcademySubject subject, AcademyFile file) {
    _files[file.id] = DownloadedFile(
      fileId: file.id,
      subjectId: subject.id,
      subjectTitle: subject.title,
      title: file.title,
      kind: file.kind,
      sizeBytes: file.sizeBytes,
      path: '/cache/pdfs/${subject.id}/${file.id}/${safePdfName(file.title)}',
    );
  }

  @override
  Future<void> open(String? ownerId) async {
    _open = true;
    if (ownerId != null) _owner = ownerId;
  }

  @override
  bool get isOpen => _open;

  @override
  String get owner => _owner;

  @override
  Duration get bodyIdleTimeout => const Duration(seconds: 30);

  @override
  List<DownloadedFile> get files => List.unmodifiable(_files.values);

  @override
  DownloadedFile? fileOf(String fileId) => _files[fileId];

  @override
  Future<DownloadedFile> download({
    required AcademySubject subject,
    required AcademyFile file,
    required Future<void> cancel,
    void Function(int received, int total)? onProgress,
  }) async {
    downloads.add(file.id);
    var cancelled = false;
    unawaited(cancel.then((_) => cancelled = true));
    progress = onProgress;
    onProgress?.call(0, file.sizeBytes);
    final g = gate;
    if (g != null) await Future.any([g.future, cancel]);
    if (cancelled) throw const DownloadCancelled();
    if (error != null) throw error!;
    seed(subject, file);
    return _files[file.id]!;
  }

  @override
  Future<bool> exists(DownloadedFile f) async => !missing.contains(f.fileId);

  @override
  Future<void> remove(String fileId) async => _files.remove(fileId);

  @override
  Future<void> removeSubject(String subjectId) async =>
      _files.removeWhere((_, f) => f.subjectId == subjectId);

  @override
  Future<void> reconcile(AcademySubjectDetail detail) async {
    if (!detail.owned) return removeSubject(detail.id);
    final keep = {for (final f in detail.files) f.id};
    _files.removeWhere(
      (_, f) => f.subjectId == detail.id && !keep.contains(f.fileId),
    );
  }

  @override
  Future<void> clearAll() async {
    _files.clear();
    _open = false;
  }
}

class FakeOpener implements FileOpener {
  OpenResult openAnswer = OpenResult.opened;
  OpenResult shareAnswer = OpenResult.opened;
  final opened = <String>[];
  final shared = <(String, String)>[];

  @override
  Future<OpenResult> open(String path) async {
    opened.add(path);
    return openAnswer;
  }

  @override
  Future<OpenResult> share(String path, String title) async {
    shared.add((path, title));
    return shareAnswer;
  }

  @override
  bool get isSupported => true;

  @override
  TargetPlatform? get platform => TargetPlatform.android;
}
