import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/app_config_cache.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/models/academy_catalog.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/providers/files_provider.dart';
import 'package:wael_app/services/file_downloads.dart';
import 'package:wael_app/services/file_opener.dart';

import 'academy_fakes.dart';
import 'files_fakes.dart';
import 'store_safety_l10n_test.dart' show hasPaymentWord;

final pdfBytes = utf8.encode('%PDF-1.7\nhello pdf body\n%%EOF');

const sub = AcademySubject(
  id: 'sub1',
  levelKey: 'bachelor-y1',
  term: 'first',
  title: LocalizedText(ar: 'القانون المدني', en: 'Civil Law'),
  description: LocalizedText(),
  owned: true,
  counts: SubjectCounts(notes: 1),
);

const note = AcademyFile(
  id: 'file1',
  kind: 'note',
  title: LocalizedText(ar: 'مذكرة الباب الأول', en: 'Chapter one notes'),
  sizeBytes: 30,
);

/// A fetcher answering from [chunks] (with [length] as Content-Length) or
/// throwing [error]; records calls.
class FakeFetcher {
  FakeFetcher({this.chunks, this.length, this.error});

  List<List<int>>? chunks;
  int? length;
  Object? error;
  StreamController<List<int>>? controller;
  final calls = <(String, String)>[];

  Future<DownloadResponse> call(
    String subjectId,
    String fileId,
    Future<void> abort,
  ) async {
    calls.add((subjectId, fileId));
    if (error != null) throw error!;
    final c = controller;
    if (c != null) {
      return DownloadResponse(stream: c.stream, contentLength: length);
    }
    final data = chunks ?? [pdfBytes];
    return DownloadResponse(
      stream: Stream.fromIterable(data),
      contentLength: length ?? data.fold<int>(0, (n, c) => n + c.length),
    );
  }
}

AcademySubjectDetail detailJson({
  bool owned = true,
  List<String> fileIds = const ['file1'],
}) => AcademySubjectDetail.fromJson({
  'id': 'sub1',
  'level_key': 'bachelor-y1',
  'term': 'first',
  'title': {'ar': 'القانون المدني', 'en': 'Civil Law'},
  'owned': owned,
  'counts': {'videos': 0, 'books': 0, 'notes': fileIds.length},
  'videos': <Object>[],
  'files': [
    for (final id in fileIds)
      {
        'id': id,
        'kind': 'note',
        'title': {'ar': 'م', 'en': 'n'},
        'size_bytes': 10,
      },
  ],
});

void main() {
  group('app-config features.files (fail closed)', () {
    test('only a real boolean true turns it on', () {
      AppConfigData parse(Object? features) => AppConfigData.fromJson({
        'terms_url': 'https://x.app/t',
        'privacy_url': 'https://x.app/p',
        'features': ?features,
      });
      expect(parse({'files': true}).filesEnabled, isTrue);
      expect(parse(null).filesEnabled, isFalse);
      expect(parse({'files': false}).filesEnabled, isFalse);
      expect(parse({'files': 'true'}).filesEnabled, isFalse);
      expect(parse({'files': 1}).filesEnabled, isFalse);
      expect(parse({}).filesEnabled, isFalse);
      expect(parse(['files']).filesEnabled, isFalse);
      expect(parse('files').filesEnabled, isFalse);
      // Unknown features are ignored.
      expect(parse({'files': true, 'future': 1}).filesEnabled, isTrue);
    });

    test('today\'s production app-config (no features) parses to off', () {
      final c = AppConfigData.fromJson({
        'show_prices': false,
        'support_whatsapp_url': 'https://wa.me/201000000000',
        'terms_url': 'https://legal.elmetracademy.app/terms',
        'privacy_url': 'https://legal.elmetracademy.app/privacy',
      });
      expect(c.filesEnabled, isFalse);
      expect(c.termsUrl, 'https://legal.elmetracademy.app/terms');
    });

    test('survives the cache round trip', () {
      const on = AppConfigData(filesEnabled: true);
      final back = AppConfigData.fromJson(on.toJson());
      expect(back.filesEnabled, isTrue);
      expect(
        AppConfigData.fromJson(const AppConfigData().toJson()).filesEnabled,
        isFalse,
      );
    });

    test('provider: unreachable config and no cache is off', () async {
      final repo = fake()..appConfigError = const SocketException('down');
      final p = AppConfigProvider(
        repository: repo,
        cache: MemoryAppConfigCache(),
        versionReader: () async => '1.0.0',
      );
      await p.load();
      expect(p.filesEnabled, isFalse);
    });

    test('provider: the server flag turns it on', () async {
      final repo = fake()
        ..appConfigData = const AppConfigData(filesEnabled: true);
      final p = AppConfigProvider(
        repository: repo,
        cache: MemoryAppConfigCache(),
        versionReader: () async => '1.0.0',
      );
      await p.load();
      expect(p.filesEnabled, isTrue);
    });
  });

  group('ApiClient.download', () {
    ApiClient client(
      MockClient mock, {
      Future<RefreshOutcome> Function()? refresh,
      Future<void> Function()? logout,
    }) => ApiClient(
      baseUrl: 'https://gw.test',
      client: mock,
      accessTokenReader: () async => 'tok',
      refreshWithOutcome: refresh,
      forceLogout: logout,
    );

    test('streams the body with auth and the documented path', () async {
      late http.BaseRequest seen;
      final api = client(
        MockClient((req) async {
          seen = req;
          return http.Response.bytes(
            pdfBytes,
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }),
      );
      final res = await httpPdfFetcher(api)(
        'sub1',
        'file1',
        Completer<void>().future,
      );
      final body = await res.stream.expand((c) => c).toList();
      expect(body, pdfBytes);
      expect(res.contentLength, pdfBytes.length);
      expect(
        seen.url.toString(),
        'https://gw.test/api/v1/academy/subjects/sub1/files/file1/download',
      );
      expect(seen.method, 'GET');
      expect(seen.headers['Authorization'], 'Bearer tok');
      expect(seen.headers['Accept'], 'application/pdf');
    });

    test('a 401 refreshes once and retries', () async {
      var n = 0;
      var refreshed = 0;
      final api = client(
        MockClient((req) async {
          n++;
          if (n == 1) {
            return http.Response('{"error":"unauthorized"}', 401);
          }
          return http.Response.bytes(pdfBytes, 200);
        }),
        refresh: () async {
          refreshed++;
          return RefreshOutcome.success;
        },
      );
      final res = await api.download('/x');
      expect(await res.stream.expand((c) => c).toList(), pdfBytes);
      expect(refreshed, 1);
      expect(n, 2);
    });

    test('a rejected refresh logs out once and surfaces 401', () async {
      var logouts = 0;
      final api = client(
        MockClient((_) async => http.Response('{"error":"x"}', 401)),
        refresh: () async => RefreshOutcome.permanentFailure,
        logout: () async => logouts++,
      );
      await expectLater(
        api.download('/x'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 's', 401)),
      );
      expect(logouts, 1);
    });

    for (final (status, code) in [
      (403, 'forbidden'),
      (404, 'not_found'),
      (413, 'too_large'),
      (429, 'rate_limited'),
      (503, 'service_unavailable'),
      (418, 'brand_new_code'),
    ]) {
      test('$status surfaces as ApiException', () async {
        final api = client(
          MockClient(
            (_) async => http.Response(
              jsonEncode({'error': 'raw server text', 'code': code}),
              status,
              headers: status == 429 ? {'retry-after': '42'} : {},
            ),
          ),
        );
        await expectLater(
          api.download('/x'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'status', status)
                .having((e) => e.code, 'code', code)
                .having(
                  (e) => e.retryAfterSeconds,
                  'retry',
                  status == 429 ? 42 : null,
                ),
          ),
        );
      });
    }

    test('a hung server times out as a network error', () async {
      final api = ApiClient(
        baseUrl: 'https://gw.test',
        client: MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 20),
      );
      await expectLater(
        api.download('/x'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'timeout')),
      );
    });
  });

  group('FileDownloadStore', () {
    late Directory tmp;
    late FakeFetcher fetcher;
    late FileDownloadStore store;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('pdfs_test');
      fetcher = FakeFetcher();
      store = FileDownloadStore(
        cacheRoot: () async => tmp,
        fetcher: fetcher.call,
        bodyIdleTimeout: const Duration(milliseconds: 200),
      );
      await store.open('user-a');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    List<FileSystemEntity> leftovers() => tmp
        .listSync(recursive: true)
        .where((e) => e.path.endsWith('.part'))
        .toList();

    test('writes a complete PDF into <cache>/pdfs and indexes it', () async {
      fetcher.chunks = [pdfBytes.sublist(0, 3), pdfBytes.sublist(3)];
      final progress = <(int, int)>[];
      final saved = await store.download(
        subject: sub,
        file: note,
        cancel: Completer<void>().future,
        onProgress: (r, t) => progress.add((r, t)),
      );
      expect(saved.path, startsWith('${tmp.path}/pdfs/sub1/file1/'));
      expect(saved.path, endsWith('مذكرة الباب الأول.pdf'));
      expect(await File(saved.path).readAsBytes(), pdfBytes);
      expect(progress.first, (0, pdfBytes.length));
      expect(progress.last, (pdfBytes.length, pdfBytes.length));
      expect(store.fileOf('file1')?.subjectTitle.en, 'Civil Law');
      expect(leftovers(), isEmpty);

      // A new store instance (app restart, offline) finds it again.
      final again = FileDownloadStore(
        cacheRoot: () async => tmp,
        fetcher: fetcher.call,
      );
      await again.open(null);
      expect(again.fileOf('file1')?.path, saved.path);
      expect(again.owner, 'user-a');
    });

    test('a body that is not a PDF is refused and removed', () async {
      fetcher.chunks = [utf8.encode('<html>nope</html>')];
      await expectLater(
        store.download(
          subject: sub,
          file: note,
          cancel: Completer<void>().future,
        ),
        throwsA(
          isA<DownloadException>().having(
            (e) => e.failure,
            'f',
            DownloadFailure.notPdf,
          ),
        ),
      );
      expect(store.fileOf('file1'), isNull);
      expect(leftovers(), isEmpty);
    });

    test('a body shorter than Content-Length is incomplete', () async {
      fetcher
        ..chunks = [pdfBytes]
        ..length = pdfBytes.length + 100;
      await expectLater(
        store.download(
          subject: sub,
          file: note,
          cancel: Completer<void>().future,
        ),
        throwsA(
          isA<DownloadException>().having(
            (e) => e.failure,
            'f',
            DownloadFailure.incomplete,
          ),
        ),
      );
      expect(leftovers(), isEmpty);
    });

    test('a declared size over the ceiling is refused up front', () async {
      fetcher.length = FileDownloadStore.maxBytes + 1;
      await expectLater(
        store.download(
          subject: sub,
          file: note,
          cancel: Completer<void>().future,
        ),
        throwsA(
          isA<DownloadException>().having(
            (e) => e.failure,
            'f',
            DownloadFailure.tooLarge,
          ),
        ),
      );
    });

    test('cancel stops the download and keeps nothing', () async {
      fetcher
        ..controller = StreamController<List<int>>()
        ..length = 1000;
      final cancel = Completer<void>();
      final future = store.download(
        subject: sub,
        file: note,
        cancel: cancel.future,
      );
      fetcher.controller!.add(pdfBytes);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      cancel.complete();
      fetcher.controller!.add(pdfBytes);
      await expectLater(future, throwsA(isA<DownloadCancelled>()));
      await fetcher.controller!.close();
      expect(store.fileOf('file1'), isNull);
      expect(leftovers(), isEmpty);
    });

    test('a stalled body fails as a network timeout', () async {
      fetcher.controller = StreamController<List<int>>();
      await expectLater(
        store.download(
          subject: sub,
          file: note,
          cancel: Completer<void>().future,
        ),
        throwsA(isA<TimeoutException>()),
      );
      await fetcher.controller!.close();
      expect(leftovers(), isEmpty);
    });

    test('server errors pass through untouched', () async {
      fetcher.error = ApiException(statusCode: 403, message: 'x');
      await expectLater(
        store.download(
          subject: sub,
          file: note,
          cancel: Completer<void>().future,
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('unsafe ids are refused before any request', () async {
      for (final bad in ['../x', 'a/b', '', 'x' * 65, 'a b']) {
        await expectLater(
          store.download(
            subject: sub,
            file: AcademyFile(
              id: bad,
              kind: 'note',
              title: const LocalizedText(ar: 't'),
              sizeBytes: 1,
            ),
            cancel: Completer<void>().future,
          ),
          throwsA(isA<DownloadException>()),
        );
      }
      expect(fetcher.calls, isEmpty);
    });

    test('reconcile: a no-longer-owned subject loses its copies', () async {
      await store.download(
        subject: sub,
        file: note,
        cancel: Completer<void>().future,
      );
      final path = store.fileOf('file1')!.path;
      await store.reconcile(detailJson(owned: false));
      expect(store.fileOf('file1'), isNull);
      expect(await File(path).exists(), isFalse);
    });

    test('reconcile: a file gone from the subject is removed', () async {
      await store.download(
        subject: sub,
        file: note,
        cancel: Completer<void>().future,
      );
      await store.reconcile(detailJson(fileIds: ['file1']));
      expect(store.fileOf('file1'), isNotNull);
      await store.reconcile(detailJson(fileIds: ['other']));
      expect(store.fileOf('file1'), isNull);
    });

    test('another account wipes the previous copies', () async {
      await store.download(
        subject: sub,
        file: note,
        cancel: Completer<void>().future,
      );
      final path = store.fileOf('file1')!.path;
      final other = FileDownloadStore(
        cacheRoot: () async => tmp,
        fetcher: fetcher.call,
      );
      await other.open('user-b');
      expect(other.files, isEmpty);
      expect(await File(path).exists(), isFalse);
    });

    test('an unknown owner (offline start) keeps the copies', () async {
      await store.download(
        subject: sub,
        file: note,
        cancel: Completer<void>().future,
      );
      final offline = FileDownloadStore(
        cacheRoot: () async => tmp,
        fetcher: fetcher.call,
      );
      await offline.open(null);
      expect(offline.files, hasLength(1));
      await offline.open('user-a');
      expect(offline.files, hasLength(1));
    });

    test('a copy whose file vanished is dropped on open', () async {
      final saved = await store.download(
        subject: sub,
        file: note,
        cancel: Completer<void>().future,
      );
      await File(saved.path).delete();
      await store.open('user-a');
      expect(store.files, isEmpty);
    });

    test('a broken index wipes the folder', () async {
      await store.download(
        subject: sub,
        file: note,
        cancel: Completer<void>().future,
      );
      await File('${tmp.path}/pdfs/index.json').writeAsString('{broken');
      await store.open('user-a');
      expect(store.files, isEmpty);
    });

    test('clearAll deletes everything', () async {
      await store.download(
        subject: sub,
        file: note,
        cancel: Completer<void>().future,
      );
      await store.clearAll();
      expect(store.files, isEmpty);
      expect(await Directory('${tmp.path}/pdfs').exists(), isFalse);
    });

    test('safePdfName strips separators and control characters', () {
      expect(
        safePdfName(const LocalizedText(ar: 'a/b\\c:d*e?"<>|')),
        'a_b_c_d_e_____.pdf',
      );
      expect(safePdfName(const LocalizedText(ar: '../../etc')), '_.._etc.pdf');
      expect(safePdfName(const LocalizedText()), 'document.pdf');
      expect(
        safePdfName(const LocalizedText(en: 'Notes  one\n')),
        'Notes one.pdf',
      );
      final long = safePdfName(LocalizedText(ar: 'م' * 200));
      expect(long.runes.length, 84);
    });
  });

  group('ErrorMessages.forFileDownload', () {
    for (final ar in [false, true]) {
      final lang = ar ? 'ar' : 'en';
      test('[$lang] every case is localized, generic and payment-free', () {
        final cases = <Object, String>{
          ApiException(statusCode: 403, message: 'raw'):
              ErrorMessages.fileNotActivated(ar),
          ApiException(statusCode: 404, message: 'raw'):
              ErrorMessages.fileUnavailable(ar),
          ApiException(statusCode: 413, message: 'raw'):
              ErrorMessages.fileTooLarge(ar),
          ApiException(statusCode: 429, message: 'raw', retryAfterSeconds: 30):
              ErrorMessages.tooManyAttempts(ar, 30),
          ApiException(statusCode: 503, message: 'raw'):
              ErrorMessages.serviceUnavailable(ar),
          ApiException(statusCode: -1, message: 'raw', code: 'timeout'):
              ErrorMessages.networkError(ar),
          ApiException(statusCode: 418, message: 'raw', code: 'new_code'):
              ErrorMessages.requestFailed(ar),
          const SocketException('raw'): ErrorMessages.networkError(ar),
          TimeoutException('raw'): ErrorMessages.networkError(ar),
          http.ClientException('raw'): ErrorMessages.networkError(ar),
          DownloadException(DownloadFailure.notPdf):
              ErrorMessages.fileIncomplete(ar),
          DownloadException(DownloadFailure.incomplete):
              ErrorMessages.fileIncomplete(ar),
          DownloadException(DownloadFailure.tooLarge):
              ErrorMessages.fileTooLarge(ar),
          DownloadException(DownloadFailure.storage): ErrorMessages.fileStorage(
            ar,
          ),
          DownloadException(DownloadFailure.invalidId):
              ErrorMessages.requestFailed(ar),
        };
        for (final e in cases.entries) {
          final msg = ErrorMessages.forFileDownload(e.key, isArabic: ar);
          expect(msg, e.value, reason: '${e.key}');
          expect(msg, isNot(contains('raw')));
          expect(hasPaymentWord(msg), isFalse, reason: msg);
          if (ar) expect(RegExp('[؀-ۿ]').hasMatch(msg), isTrue);
        }
      });
    }
  });

  group('FileOpener', () {
    const channel = MethodChannel(FileOpener.channelName);
    TestWidgetsFlutterBinding.ensureInitialized();

    void answer(Object? Function(MethodCall) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (c) async => handler(c));
    }

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('maps the native answers', () async {
      final opener = FileOpener(platform: TargetPlatform.android);
      final calls = <MethodCall>[];
      answer((c) {
        calls.add(c);
        return c.method == 'open' ? 'no_app' : 'opened';
      });
      expect(await opener.open('/p.pdf'), OpenResult.noApp);
      expect(await opener.share('/p.pdf', 'T'), OpenResult.opened);
      expect(calls[0].arguments, {'path': '/p.pdf'});
      expect(calls[1].arguments, {'path': '/p.pdf', 'title': 'T'});
      answer((_) => 'something_new');
      expect(await opener.open('/p.pdf'), OpenResult.failed);
      answer((_) => throw PlatformException(code: 'boom'));
      expect(await opener.open('/p.pdf'), OpenResult.failed);
    });

    test('calls the channel on iOS too', () async {
      final opener = FileOpener(platform: TargetPlatform.iOS);
      expect(opener.isSupported, isTrue);
      answer((_) => 'opened');
      expect(await opener.open('/p.pdf'), OpenResult.opened);
      expect(await opener.share('/p.pdf', 'T'), OpenResult.opened);
    });

    test('is a no-op off Android and iOS', () async {
      for (final platform in [
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.fuchsia,
      ]) {
        final opener = FileOpener(platform: platform);
        expect(opener.isSupported, isFalse, reason: '$platform');
        expect(await opener.open('/p.pdf'), OpenResult.failed);
      }
    });
  });

  group('FilesProvider', () {
    late Directory tmp;
    late FakeFetcher fetcher;
    late FakeOpener opener;
    late FilesProvider files;
    late FileDownloadStore store;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('files_provider_test');
      fetcher = FakeFetcher();
      opener = FakeOpener();
      store = FileDownloadStore(
        cacheRoot: () async => tmp,
        fetcher: fetcher.call,
      );
      files = FilesProvider(store: store, opener: opener);
      await files.bindUser('user-a');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('download -> downloaded -> open and share offline', () async {
      await files.download(sub, note);
      expect(files.isDownloaded('file1'), isTrue);
      expect(files.stateOf('file1').phase, FileDownloadPhase.idle);
      fetcher.error = const SocketException('offline');
      expect(await files.open('file1'), OpenResult.opened);
      expect(await files.share('file1', isArabic: true), OpenResult.opened);
      expect(opener.shared.single.$2, 'مذكرة الباب الأول');
      expect(fetcher.calls, hasLength(1));
    });

    test('no PDF app is reported (the UI offers Share)', () async {
      await files.download(sub, note);
      opener.openAnswer = OpenResult.noApp;
      expect(await files.open('file1'), OpenResult.noApp);
      expect(files.isDownloaded('file1'), isTrue);
    });

    test('a vanished cached file is forgotten after a failed open', () async {
      await files.download(sub, note);
      await File(files.downloadedOf('file1')!.path).delete();
      opener.openAnswer = OpenResult.failed;
      expect(await files.open('file1'), OpenResult.failed);
      expect(files.isDownloaded('file1'), isFalse);
    });

    test('failures keep the error for the tile', () async {
      fetcher.error = ApiException(statusCode: 429, message: 'x');
      await files.download(sub, note);
      final s = files.stateOf('file1');
      expect(s.phase, FileDownloadPhase.failed);
      expect(s.error, isA<ApiException>());
      files.dismissError('file1');
      expect(files.stateOf('file1').phase, FileDownloadPhase.idle);
    });

    test('403 and 404 drop an older copy and refresh the subject', () async {
      await files.download(sub, note);
      final repo = fake();
      final catalog = AcademyCatalogProvider(repo);
      files.attachCatalog(catalog);
      for (final status in [403, 404]) {
        fetcher.error = ApiException(statusCode: status, message: 'x');
        await files.download(sub, note);
        expect(files.isDownloaded('file1'), isFalse);
        expect(files.stateOf('file1').phase, FileDownloadPhase.failed);
      }
      await Future<void>.delayed(Duration.zero);
      expect(repo.detailCalls, greaterThanOrEqualTo(1));
    });

    test('cancel while running returns to idle and keeps nothing', () async {
      fetcher
        ..controller = StreamController<List<int>>()
        ..length = 1000;
      final run = files.download(sub, note);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(files.stateOf('file1').phase, FileDownloadPhase.downloading);
      fetcher.controller!.add(pdfBytes);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(files.stateOf('file1').received, pdfBytes.length);
      expect(
        files.stateOf('file1').fraction,
        closeTo(pdfBytes.length / 1000, 1e-9),
      );
      files.cancel('file1');
      fetcher.controller!.add(pdfBytes);
      await run;
      await fetcher.controller!.close();
      expect(files.stateOf('file1').phase, FileDownloadPhase.idle);
      expect(files.isDownloaded('file1'), isFalse);
    });

    test(
      'a fresh detail that no longer owns the subject removes copies',
      () async {
        await files.download(sub, note);
        final repo = fake()
          ..detailJson['sub1'] = {
            'id': 'sub1',
            'level_key': 'bachelor-y1',
            'term': 'first',
            'title': {'ar': 'x', 'en': 'x'},
            'owned': false,
            'counts': {'videos': 0, 'books': 0, 'notes': 1},
            'videos': <Object>[],
            'files': <Object>[],
          };
        final catalog = AcademyCatalogProvider(repo);
        files.attachCatalog(catalog);
        await catalog.loadDetail('sub1');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(files.isDownloaded('file1'), isFalse);
      },
    );

    test('a 404 subject detail removes its copies', () async {
      await files.download(sub, note);
      final repo = fake()
        ..detailError = ApiException(statusCode: 404, message: 'x');
      final catalog = AcademyCatalogProvider(repo);
      files.attachCatalog(catalog);
      await catalog.loadDetail('sub1');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(files.isDownloaded('file1'), isFalse);
    });

    test('an offline detail error keeps the copies', () async {
      await files.download(sub, note);
      final repo = fake()..detailError = const SocketException('offline');
      final catalog = AcademyCatalogProvider(repo);
      files.attachCatalog(catalog);
      await catalog.loadDetail('sub1');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(files.isDownloaded('file1'), isTrue);
    });

    test(
      'a fresh subject list that marks it not owned removes copies',
      () async {
        await files.download(sub, note);
        final repo = fake()
          ..subjectsByLevel = {
            'bachelor-y1': [subject('sub1', 'bachelor-y1')],
          };
        final catalog = AcademyCatalogProvider(repo);
        files.attachCatalog(catalog);
        await catalog.reload();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(files.isDownloaded('file1'), isFalse);
      },
    );

    test('sign-out clears every copy and cancels running downloads', () async {
      await files.download(sub, note);
      await files.clearAll();
      expect(files.downloads, isEmpty);
      expect(files.isBound, isFalse);
      expect(await Directory('${tmp.path}/pdfs').exists(), isFalse);
    });
  });
}
