import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/models/academy_catalog.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/providers/files_provider.dart';
import 'package:wael_app/providers/home_provider.dart';
import 'package:wael_app/screens/course_detail_screen.dart';
import 'package:wael_app/screens/ebook_screen.dart';
import 'package:wael_app/screens/main_shell.dart';
import 'package:wael_app/services/file_downloads.dart';
import 'package:wael_app/services/file_opener.dart';
import 'package:wael_app/widgets/catalog_file_tile.dart';
import 'package:wael_app/widgets/file_download_tile.dart';

import 'academy_fakes.dart';
import 'files_fakes.dart';
import 'screen_harness.dart';
import 'store_safety_l10n_test.dart' show hasPaymentWord;
import 'widget_layer_harness.dart';

const owned = AcademySubject(
  id: 'sub1',
  levelKey: 'bachelor-y1',
  term: 'first',
  title: LocalizedText(ar: 'القانون المدني', en: 'Civil Law'),
  description: LocalizedText(),
  owned: true,
  counts: SubjectCounts(videos: 1, books: 1, notes: 1),
);

const locked = AcademySubject(
  id: 'sub2',
  levelKey: 'bachelor-y1',
  term: 'first',
  title: LocalizedText(ar: 'القانون الجنائي', en: 'Criminal Law'),
  description: LocalizedText(),
  owned: false,
  counts: SubjectCounts(videos: 1, notes: 2),
);

const book = AcademyFile(
  id: 'b1',
  kind: 'book',
  title: LocalizedText(ar: 'كتاب المادة', en: 'Course book'),
  sizeBytes: 2 * 1024 * 1024,
);

Map<String, dynamic> ownedDetail({List<Map<String, dynamic>>? files}) =>
    detailBody(
      id: 'sub1',
      owned: true,
      files:
          files ??
          [
            {
              'id': 'b1',
              'kind': 'book',
              'title': {'ar': 'كتاب المادة', 'en': 'Course book'},
              'size_bytes': 2 * 1024 * 1024,
            },
            {
              'id': 'n1',
              'kind': 'note',
              'title': {'ar': 'مذكرة أولى', 'en': 'First notes'},
              'size_bytes': 4096,
            },
          ],
    );

FakeAcademyRepository repoWith({bool withOwned = true}) {
  final repo = FakeAcademyRepository(
    levelList: [level('bachelor-y1', 'bachelor', 1)],
    subjectsByLevel: {
      'bachelor-y1': [if (withOwned) owned, locked],
    },
  );
  repo.detailJson['sub1'] = ownedDetail();
  repo.detailJson['sub2'] = detailBody(
    id: 'sub2',
    files: [fileBody('n9', 'note')],
  );
  return repo;
}

void main() {
  for (final (name, locale, _) in kLocales) {
    final l10n = l10nFor(locale);
    final ar = locale.languageCode == 'ar';

    Future<(FilesProvider, FakeFileDownloadStore, FakeOpener)> pumpNotes(
      WidgetTester tester, {
      bool enabled = true,
      FakeAcademyRepository? repo,
      FakeFileDownloadStore? store,
      bool settle = true,
    }) async {
      final s = store ?? FakeFileDownloadStore();
      final opener = FakeOpener();
      final files = FilesProvider(store: s, opener: opener);
      await files.bindUser('user-a');
      final catalog = AcademyCatalogProvider(repo ?? repoWith());
      files.attachCatalog(catalog);
      await pumpScreen(
        tester,
        locale,
        const EbookScreen(),
        appConfig: AppConfigProvider(versionReader: () async => '1.0.0')
          ..setForTesting(AppConfigData(filesEnabled: enabled)),
        extraProviders: [
          ChangeNotifierProvider<AcademyCatalogProvider>.value(value: catalog),
          ChangeNotifierProvider<FilesProvider>.value(value: files),
        ],
        size: const Size(390, 1600),
        settle: settle,
      );
      return (files, s, opener);
    }

    Finder button(String key) => find.byKey(ValueKey(key));

    group('Notes & books tab [$name]', () {
      testWidgets('flag off: today\'s coming-soon state, no requests', (
        tester,
      ) async {
        final repo = repoWith();
        await pumpNotes(tester, enabled: false, repo: repo);
        expect(find.text(l10n.comingSoon), findsOneWidget);
        expect(find.text(l10n.ebookComingSoon), findsOneWidget);
        expect(find.text(l10n.navNotesAndBooks), findsNothing);
        expect(find.byType(FileDownloadTile), findsNothing);
        expect(repo.levelsCalls, 0);
        expect(repo.detailCalls, 0);
      });

      testWidgets('flag on: owned files grouped by subject, locked hidden', (
        tester,
      ) async {
        await pumpNotes(tester);
        expect(find.text(l10n.navNotesAndBooks), findsOneWidget);
        expect(find.text(ar ? 'القانون المدني' : 'Civil Law'), findsOneWidget);
        expect(find.text(ar ? 'كتاب المادة' : 'Course book'), findsOneWidget);
        expect(find.text(ar ? 'مذكرة أولى' : 'First notes'), findsOneWidget);
        expect(find.byType(FileDownloadTile), findsNWidgets(2));
        // The unowned subject and its files are not in the library.
        expect(
          find.text(ar ? 'القانون الجنائي' : 'Criminal Law'),
          findsNothing,
        );
        expect(find.textContaining('n9'), findsNothing);
        expect(button('download-b1'), findsOneWidget);
        expect(find.text(l10n.fileOpen), findsNothing);
      });

      testWidgets('flag on with nothing owned: empty state', (tester) async {
        await pumpNotes(tester, repo: repoWith(withOwned: false));
        expect(find.text(l10n.filesEmpty), findsOneWidget);
        expect(find.byType(FileDownloadTile), findsNothing);
        expect(hasPaymentWord(l10n.filesEmpty), isFalse);
      });

      testWidgets('download shows progress and cancel, then Open and Share', (
        tester,
      ) async {
        final store = FakeFileDownloadStore()..gate = Completer<void>();
        final (_, _, opener) = await pumpNotes(tester, store: store);
        await tester.tap(button('download-b1'));
        await tester.pump();
        store.progress!(1024 * 1024, 2 * 1024 * 1024);
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text(l10n.fileDownloading(50)), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(button('cancel-b1'), findsOneWidget);

        store.gate!.complete();
        await tester.pumpAndSettle();
        expect(find.text(l10n.fileDownloaded), findsOneWidget);
        await tester.tap(button('open-b1'));
        await tester.pumpAndSettle();
        expect(opener.opened.single, endsWith('.pdf'));
        await tester.tap(button('share-b1'));
        await tester.pumpAndSettle();
        expect(opener.shared.single.$2, ar ? 'كتاب المادة' : 'Course book');
      });

      testWidgets('cancel returns to Download and keeps nothing', (
        tester,
      ) async {
        final store = FakeFileDownloadStore()..gate = Completer<void>();
        await pumpNotes(tester, store: store);
        await tester.tap(button('download-b1'));
        await tester.pump();
        await tester.tap(button('cancel-b1'));
        await tester.pumpAndSettle();
        expect(button('download-b1'), findsOneWidget);
        expect(store.fileOf('b1'), isNull);
      });

      testWidgets('no PDF app: localized message with a Share action', (
        tester,
      ) async {
        final store = FakeFileDownloadStore()..seed(owned, book);
        final (_, _, opener) = await pumpNotes(tester, store: store);
        opener.openAnswer = OpenResult.noApp;
        await tester.tap(button('open-b1'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));
        expect(find.text(l10n.noPdfApp), findsOneWidget);
        await tester.tap(find.widgetWithText(SnackBarAction, l10n.fileShare));
        await tester.pumpAndSettle();
        expect(opener.shared, hasLength(1));
      });

      final failures = <String, (Object, String)>{
        '403': (
          ApiException(statusCode: 403, message: 'raw'),
          ErrorMessages.fileNotActivated(ar),
        ),
        '404': (
          ApiException(statusCode: 404, message: 'raw'),
          ErrorMessages.fileUnavailable(ar),
        ),
        '413': (
          ApiException(statusCode: 413, message: 'raw'),
          ErrorMessages.fileTooLarge(ar),
        ),
        '429': (
          ApiException(statusCode: 429, message: 'raw', retryAfterSeconds: 9),
          ErrorMessages.tooManyAttempts(ar, 9),
        ),
        'network': (
          const SocketException('raw'),
          ErrorMessages.networkError(ar),
        ),
        'unknown code': (
          ApiException(statusCode: 422, message: 'raw', code: 'new_code'),
          ErrorMessages.requestFailed(ar),
        ),
        'not a pdf': (
          DownloadException(DownloadFailure.notPdf),
          ErrorMessages.fileIncomplete(ar),
        ),
      };
      for (final e in failures.entries) {
        testWidgets('download failure ${e.key}: localized message + retry', (
          tester,
        ) async {
          final store = FakeFileDownloadStore()..error = e.value.$1;
          await pumpNotes(tester, store: store);
          await tester.tap(button('download-b1'));
          await tester.pumpAndSettle();
          expect(find.text(e.value.$2), findsOneWidget);
          expect(find.textContaining('raw'), findsNothing);
          expect(hasPaymentWord(e.value.$2), isFalse);
          // Download again is offered.
          store.error = null;
          await tester.tap(button('download-b1'));
          await tester.pumpAndSettle();
          expect(button('open-b1'), findsOneWidget);
        });
      }

      testWidgets('offline: downloaded copies list and open without network', (
        tester,
      ) async {
        final repo = repoWith()..levelsError = const SocketException('off');
        final store = FakeFileDownloadStore()..seed(owned, book);
        final (_, _, opener) = await pumpNotes(
          tester,
          repo: repo,
          store: store,
        );
        expect(find.text(ar ? 'القانون المدني' : 'Civil Law'), findsOneWidget);
        expect(find.text(ar ? 'كتاب المادة' : 'Course book'), findsOneWidget);
        await tester.tap(button('open-b1'));
        await tester.pumpAndSettle();
        expect(opener.opened, hasLength(1));
      });

      testWidgets('offline with nothing downloaded: error with retry', (
        tester,
      ) async {
        final repo = repoWith()..levelsError = const SocketException('off');
        await pumpNotes(tester, repo: repo);
        expect(find.text(ErrorMessages.networkError(ar)), findsOneWidget);
        expect(find.text(l10n.retry), findsOneWidget);
      });

      testWidgets('a refresh that shows the subject not owned drops copies', (
        tester,
      ) async {
        final repo = repoWith();
        repo.subjectsByLevel['bachelor-y1'] = [subject('sub1', 'bachelor-y1')];
        final store = FakeFileDownloadStore()..seed(owned, book);
        await pumpNotes(tester, repo: repo, store: store);
        await tester.pumpAndSettle();
        expect(store.fileOf('b1'), isNull);
        expect(find.text(l10n.filesEmpty), findsOneWidget);
      });

      testWidgets('a file removed from the subject drops its copy', (
        tester,
      ) async {
        final repo = repoWith();
        repo.detailJson['sub1'] = ownedDetail(files: [fileBody('n1', 'note')]);
        final store = FakeFileDownloadStore()..seed(owned, book);
        await pumpNotes(tester, repo: repo, store: store);
        await tester.pumpAndSettle();
        expect(store.fileOf('b1'), isNull);
        expect(button('open-b1'), findsNothing);
      });

      testWidgets('no overflow on a small phone', (tester) async {
        final store = FakeFileDownloadStore()..seed(owned, book);
        await pumpNotes(tester, store: store);
        tester.view.physicalSize = const Size(320, 568);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    });

    group('Subject detail files [$name]', () {
      Future<FakeFileDownloadStore> pumpDetail(
        WidgetTester tester, {
        required bool isOwned,
        required bool enabled,
      }) async {
        final repo = fake();
        repo.detailJson['d1'] = isOwned
            ? (ownedDetail()..['id'] = 'd1')
            : detailBody(files: [fileBody('b1', 'book')]);
        final store = FakeFileDownloadStore();
        final files = FilesProvider(store: store, opener: FakeOpener());
        await files.bindUser('user-a');
        await pumpScreen(
          tester,
          locale,
          const CourseDetailScreen(courseId: 'd1'),
          appConfig: AppConfigProvider()
            ..setForTesting(AppConfigData(filesEnabled: enabled)),
          extraProviders: [
            ChangeNotifierProvider<AcademyCatalogProvider>.value(
              value: AcademyCatalogProvider(repo),
            ),
            ChangeNotifierProvider<FilesProvider>.value(value: files),
            ChangeNotifierProvider(create: (_) => HomeProvider()),
          ],
          size: const Size(390, 2400),
        );
        final tab = find.text(l10n.tabBooks);
        await tester.ensureVisible(tab);
        await tester.tap(tab);
        await tester.pumpAndSettle();
        return store;
      }

      testWidgets('owned + flag on: download actions', (tester) async {
        final store = await pumpDetail(tester, isOwned: true, enabled: true);
        expect(find.byType(FileDownloadTile), findsOneWidget);
        await tester.tap(button('download-b1'));
        await tester.pumpAndSettle();
        expect(store.downloads, ['b1']);
        expect(button('open-b1'), findsOneWidget);
        expect(button('share-b1'), findsOneWidget);
      });

      testWidgets('not owned + flag on: titles only, no download', (
        tester,
      ) async {
        await pumpDetail(tester, isOwned: false, enabled: true);
        expect(find.byType(FileDownloadTile), findsNothing);
        expect(find.byType(CatalogFileTile), findsOneWidget);
        expect(button('download-b1'), findsNothing);
        expect(find.text(l10n.fileDownload), findsNothing);
      });

      testWidgets('owned + flag off: unchanged (no download)', (tester) async {
        await pumpDetail(tester, isOwned: true, enabled: false);
        expect(find.byType(FileDownloadTile), findsNothing);
        expect(find.byType(CatalogFileTile), findsOneWidget);
      });
    });

    group('Tab label [$name]', () {
      for (final enabled in [false, true]) {
        testWidgets('features.files=$enabled', (tester) async {
          final files = FilesProvider(
            store: FakeFileDownloadStore(),
            opener: FakeOpener(),
          );
          await pumpScreen(
            tester,
            locale,
            const MainShell(),
            appConfig: AppConfigProvider(versionReader: () async => '1.0.0')
              ..setForTesting(AppConfigData(filesEnabled: enabled)),
            extraProviders: [
              ChangeNotifierProvider(
                create: (_) => AcademyCatalogProvider(fake()),
              ),
              ChangeNotifierProvider<FilesProvider>.value(value: files),
              ChangeNotifierProvider(create: (_) => HomeProvider()),
            ],
          );
          // The bottom bar shows labels in upper case (a no-op in Arabic).
          String label(String s) => s.toUpperCase();
          final shown = enabled ? l10n.navNotesAndBooks : l10n.navNotes;
          final hidden = enabled ? l10n.navNotes : l10n.navNotesAndBooks;
          expect(find.text(label(shown)), findsWidgets);
          expect(find.text(label(hidden)), findsNothing);
        });
      }
    });
  }
}
