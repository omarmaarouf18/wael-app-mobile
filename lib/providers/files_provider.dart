import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/academy_catalog.dart';
import '../services/file_downloads.dart';
import '../services/file_opener.dart';
import 'academy_catalog_provider.dart';

enum FileDownloadPhase { idle, downloading, failed }

/// Live state of one file's download in this session. A finished download
/// is not kept here: it is a [DownloadedFile] in the store.
class FileDownloadState {
  const FileDownloadState({
    this.phase = FileDownloadPhase.idle,
    this.received = 0,
    this.total = 0,
    this.error,
  });

  final FileDownloadPhase phase;
  final int received;

  /// 0 when the size is unknown.
  final int total;

  /// The failure behind [FileDownloadPhase.failed]; map it with
  /// `ErrorMessages.forFileDownload`.
  final Object? error;

  /// 0..1, or null while the size is unknown.
  double? get fraction =>
      total > 0 ? (received / total).clamp(0.0, 1.0).toDouble() : null;
}

/// Notes and books (SPEC Phase 5 client, behind `features.files`): downloads
/// to the app-private cache with progress and cancel, then Open (the phone's
/// PDF app) and Share (system share sheet). The server decides ownership on
/// every download (R3); this class never unlocks anything, it only removes
/// local copies when a fresh server answer shows a subject is no longer
/// owned or a file is gone (best effort), and wipes them on sign-out.
class FilesProvider extends ChangeNotifier {
  FilesProvider({required FileDownloadStore store, FileOpener? opener})
    // ignore: prefer_initializing_formals, public `store:` maps to `_store`
    : _store = store,
      _opener = opener ?? FileOpener();

  final FileDownloadStore _store;
  final FileOpener _opener;

  final Map<String, FileDownloadState> _states = {};
  final Map<String, Completer<void>> _cancels = {};
  String? _owner;
  Future<void>? _opening;

  AcademyCatalogProvider? _catalog;
  final Map<String, AcademySubjectDetail> _seenDetails = {};
  bool _seenFreshCatalog = false;

  FileDownloadState stateOf(String fileId) =>
      _states[fileId] ?? const FileDownloadState();

  DownloadedFile? downloadedOf(String fileId) => _store.fileOf(fileId);

  bool isDownloaded(String fileId) => _store.fileOf(fileId) != null;

  /// Every cached copy (for the notes tab offline).
  List<DownloadedFile> get downloads => _store.files;

  /// Binds the store to the signed-in user (`/auth/me` id). An unknown id
  /// (offline start, `''` or `'pending'`) opens the existing copies as they
  /// are; the first known id is recorded, and a different known id wipes
  /// the previous account's copies.
  Future<void> bindUser(String userId) {
    final known = userId.isNotEmpty && userId != 'pending';
    final key = known ? userId : '';
    if (_owner != null && (_owner == key || !known)) {
      return _opening ?? Future.value();
    }
    _owner = key;
    final future = _store
        .open(known ? userId : null)
        .catchError((_) {})
        .whenComplete(notifyListeners);
    _opening = future;
    return future;
  }

  /// True once [bindUser] ran (the user is signed in).
  bool get isBound => _owner != null;

  /// Sign-out: cancels running downloads and deletes every cached PDF.
  Future<void> clearAll({bool notify = true}) async {
    for (final c in _cancels.values) {
      if (!c.isCompleted) c.complete();
    }
    _cancels.clear();
    _states.clear();
    _owner = null;
    _opening = null;
    _seenDetails.clear();
    _seenFreshCatalog = false;
    try {
      await _store.clearAll();
    } catch (_) {}
    if (notify) notifyListeners();
  }

  /// Watches the catalog for fresh server answers and removes local copies
  /// they rule out. Called once by the provider wiring.
  void attachCatalog(AcademyCatalogProvider catalog) {
    if (identical(_catalog, catalog)) return;
    _catalog?.removeListener(_onCatalog);
    _catalog = catalog;
    catalog.addListener(_onCatalog);
  }

  void _onCatalog() {
    final catalog = _catalog;
    if (catalog == null || !_store.isOpen) return;
    // Fresh subject list: drop copies of subjects it lists as not owned.
    // A cached (stale) list is not a server answer and is ignored.
    final fresh = catalog.isReady && !catalog.isStale;
    if (fresh && !_seenFreshCatalog) {
      final notOwned = <String>{};
      for (final f in _store.files) {
        final s = catalog.findSubject(f.subjectId);
        if (s != null && !s.owned) notOwned.add(f.subjectId);
      }
      for (final id in notOwned) {
        unawaited(_store.removeSubject(id).then((_) => notifyListeners()));
      }
    }
    _seenFreshCatalog = fresh;
    // Fresh subject details (never cached), and 404 for a gone subject.
    final subjectIds = {for (final f in _store.files) f.subjectId};
    for (final id in subjectIds) {
      final state = catalog.detailOf(id);
      final detail = state.detail;
      if (state.status == LoadStatus.ready && detail != null) {
        if (identical(_seenDetails[id], detail)) continue;
        _seenDetails[id] = detail;
        unawaited(_store.reconcile(detail).then((_) => notifyListeners()));
      } else if (state.status == LoadStatus.error) {
        final e = state.error;
        if (e is ApiException && e.statusCode == 404) {
          unawaited(_store.removeSubject(id).then((_) => notifyListeners()));
        }
      }
    }
  }

  /// Starts downloading [file] of the owned [subject]. A second call while
  /// it runs does nothing.
  Future<void> download(AcademySubject subject, AcademyFile file) async {
    if (stateOf(file.id).phase == FileDownloadPhase.downloading) return;
    await (_opening ?? Future.value());
    final cancel = Completer<void>();
    _cancels[file.id] = cancel;
    _states[file.id] = FileDownloadState(
      phase: FileDownloadPhase.downloading,
      total: file.sizeBytes,
    );
    notifyListeners();
    var lastStep = -1;
    try {
      await _store.download(
        subject: subject,
        file: file,
        cancel: cancel.future,
        onProgress: (received, total) {
          if (!identical(_cancels[file.id], cancel)) return;
          _states[file.id] = FileDownloadState(
            phase: FileDownloadPhase.downloading,
            received: received,
            total: total,
          );
          // Rebuild once per whole percent (or per 64 KiB when the size is
          // unknown), not on every chunk.
          final step = total > 0 ? received * 100 ~/ total : received >> 16;
          if (step != lastStep) {
            lastStep = step;
            notifyListeners();
          }
        },
      );
      if (!identical(_cancels[file.id], cancel)) return;
      _states.remove(file.id);
    } on DownloadCancelled {
      if (!identical(_cancels[file.id], cancel)) return;
      _states.remove(file.id);
    } catch (e) {
      if (!identical(_cancels[file.id], cancel)) return;
      _states[file.id] = FileDownloadState(
        phase: FileDownloadPhase.failed,
        error: e,
      );
      // The server says the file is not (or no longer) the student's, or
      // gone: drop any older copy and refresh the subject.
      if (e is ApiException && (e.statusCode == 403 || e.statusCode == 404)) {
        await _store.remove(file.id);
        unawaited(_catalog?.loadDetail(subject.id, force: true));
      }
    } finally {
      if (identical(_cancels[file.id], cancel)) _cancels.remove(file.id);
    }
    notifyListeners();
  }

  /// Cancels a running download; nothing is kept.
  void cancel(String fileId) {
    final c = _cancels.remove(fileId);
    if (c != null && !c.isCompleted) c.complete();
    _states.remove(fileId);
    notifyListeners();
  }

  /// Clears a failed state (the tile shows Download again).
  void dismissError(String fileId) {
    if (_states.remove(fileId) != null) notifyListeners();
  }

  /// Opens the cached copy in the phone's PDF app. Works offline. A copy
  /// whose file vanished (the system cleared the cache) is forgotten and
  /// answers [OpenResult.failed].
  Future<OpenResult> open(String fileId) async {
    final f = _store.fileOf(fileId);
    if (f == null) return OpenResult.failed;
    final result = await _opener.open(f.path);
    if (result == OpenResult.failed) await _forgetIfMissing(f);
    return result;
  }

  /// Shares the cached copy through the system share sheet. Works offline.
  Future<OpenResult> share(String fileId, {required bool isArabic}) async {
    final f = _store.fileOf(fileId);
    if (f == null) return OpenResult.failed;
    final result = await _opener.share(f.path, f.title.resolve(isArabic));
    if (result == OpenResult.failed) await _forgetIfMissing(f);
    return result;
  }

  Future<void> _forgetIfMissing(DownloadedFile f) async {
    if (!await _store.exists(f)) {
      await _store.remove(f.fileId);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _catalog?.removeListener(_onCatalog);
    for (final c in _cancels.values) {
      if (!c.isCompleted) c.complete();
    }
    super.dispose();
  }
}
