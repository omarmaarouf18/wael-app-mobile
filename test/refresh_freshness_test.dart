import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/core/refresh_when_visible.dart';
import 'package:wael_app/models/academy_catalog.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/models/notification_model.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/providers/files_provider.dart';
import 'package:wael_app/providers/home_provider.dart';
import 'package:wael_app/providers/notifications_provider.dart';
import 'package:wael_app/repositories/notification_repository.dart';
import 'package:wael_app/screens/main_shell.dart';
import 'package:wael_app/screens/notifications_screen.dart';
import 'package:wael_app/widgets/app_bottom_nav.dart';
import 'package:wael_app/widgets/file_download_tile.dart';

import 'academy_fakes.dart';
import 'files_fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

// Notes & books freshness (stable-release pass 2026-10-12, spec §3): a file
// the admin adds must show without a manual reload. One test per cause in
// the spec; each failed before the RefreshWhenVisible wiring.

const _subject = AcademySubject(
  id: 'sub1',
  levelKey: 'bachelor-y1',
  term: 'first',
  title: LocalizedText(ar: 'القانون المدني', en: 'Civil Law'),
  description: LocalizedText(),
  owned: true,
  counts: SubjectCounts(videos: 0, books: 1, notes: 0),
);

/// The subject as a catalog list cached before any file existed.
const _subjectNoFiles = AcademySubject(
  id: 'sub1',
  levelKey: 'bachelor-y1',
  term: 'first',
  title: LocalizedText(ar: 'القانون المدني', en: 'Civil Law'),
  description: LocalizedText(),
  owned: true,
  counts: SubjectCounts(),
);

FakeAcademyRepository _repo({
  AcademySubject subject = _subject,
  List<Map<String, dynamic>>? files,
}) {
  final repo = FakeAcademyRepository(
    levelList: [level('bachelor-y1', 'bachelor', 1)],
    subjectsByLevel: {
      'bachelor-y1': [subject],
    },
  );
  repo.detailJson['sub1'] = detailBody(
    id: 'sub1',
    owned: true,
    files: files ?? [fileBody('b1', 'book')],
  );
  return repo;
}

/// The admin uploads a second file in the console.
void _adminAddsFile(FakeAcademyRepository repo) {
  repo.detailJson['sub1'] = detailBody(
    id: 'sub1',
    owned: true,
    files: [fileBody('b1', 'book'), fileBody('n2', 'note')],
  );
}

class _Clock {
  DateTime now = DateTime.utc(2026, 10, 12, 9);
  void advance(Duration d) => now = now.add(d);
}

class _MutableNotifRepo implements NotificationRepository {
  _MutableNotifRepo(this.items);
  List<NotificationModel> items;
  int listCalls = 0;
  Object? error;

  @override
  List<NotificationModel> initial() => const [];

  @override
  Future<List<NotificationModel>> list({int page = 1, int limit = 20}) async {
    listCalls++;
    if (error != null) throw error!;
    return items;
  }

  @override
  Future<void> markRead(String id) async {}
}

NotificationModel _notif(String id, String title) => NotificationModel(
  id: id,
  title: title,
  titleAr: title,
  body: '',
  bodyAr: '',
  timestamp: '',
  timestampAr: '',
  type: 'general',
);

Future<void> _resume(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

void main() {
  late _Clock clock;
  setUp(() {
    clock = _Clock();
    RefreshWhenVisible.clock = () => clock.now;
  });
  tearDown(() => RefreshWhenVisible.clock = DateTime.now);

  final (name, locale, _) = kLocales.first;
  final l10n = l10nFor(locale);
  String upper(String s) => s.toUpperCase();

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text(upper(label)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<AcademyCatalogProvider> pumpShell(
    WidgetTester tester,
    FakeAcademyRepository repo, {
    int initialTab = 2,
    AppConfigProvider? appConfig,
    AcademyCatalogProvider? catalog,
  }) async {
    final files = FilesProvider(
      store: FakeFileDownloadStore(),
      opener: FakeOpener(),
    );
    await files.bindUser('user-a');
    final c = catalog ?? AcademyCatalogProvider(repo);
    files.attachCatalog(c);
    await pumpScreen(
      tester,
      locale,
      MainShell(initialTab: initialTab),
      appConfig:
          appConfig ??
          (AppConfigProvider(versionReader: () async => '1.0.0')
            ..setForTesting(const AppConfigData(filesEnabled: true))),
      extraProviders: [
        ChangeNotifierProvider<AcademyCatalogProvider>.value(value: c),
        ChangeNotifierProvider<FilesProvider>.value(value: files),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
      ],
      size: const Size(600, 1400),
    );
    return c;
  }

  Finder fileTitled(String id) => find.text('File $id');

  group('Notes & books freshness [$name]', () {
    testWidgets(
      'cause 1: coming back to the tab shows a file added meanwhile',
      (tester) async {
        final repo = _repo();
        await pumpShell(tester, repo);
        expect(fileTitled('b1'), findsOneWidget);
        expect(fileTitled('n2'), findsNothing);

        _adminAddsFile(repo);
        await tapTab(tester, l10n.navHome);
        clock.advance(const Duration(seconds: 31));
        await tapTab(tester, l10n.navNotesAndBooks);

        expect(fileTitled('n2'), findsOneWidget);
      },
    );

    testWidgets('cause 1: app resume on the tab shows a file added meanwhile', (
      tester,
    ) async {
      final repo = _repo();
      await pumpShell(tester, repo);
      _adminAddsFile(repo);
      clock.advance(const Duration(seconds: 31));
      await _resume(tester);
      expect(fileTitled('n2'), findsOneWidget);
    });

    testWidgets('throttle: no refetch within 30 s of the last load', (
      tester,
    ) async {
      final repo = _repo();
      await pumpShell(tester, repo);
      final detailCalls = repo.detailCalls;
      final levelsCalls = repo.levelsCalls;
      await tapTab(tester, l10n.navHome);
      clock.advance(const Duration(seconds: 10));
      await tapTab(tester, l10n.navNotesAndBooks);
      await _resume(tester);
      expect(repo.detailCalls, detailCalls);
      expect(repo.levelsCalls, levelsCalls);
    });

    testWidgets('cause 2: a subject detail cached earlier is refetched', (
      tester,
    ) async {
      final repo = _repo();
      final catalog = AcademyCatalogProvider(repo);
      await catalog.reload();
      // The detail is cached earlier in the session (subject screen opened).
      await catalog.loadDetail('sub1');
      _adminAddsFile(repo);
      await pumpShell(tester, repo, initialTab: 0, catalog: catalog);
      clock.advance(const Duration(seconds: 31));
      await tapTab(tester, l10n.navNotesAndBooks);
      expect(fileTitled('n2'), findsOneWidget);
    });

    testWidgets('cause 3: a subject listed with zero files is still fetched', (
      tester,
    ) async {
      // The cached list says books + notes == 0; the server has a file.
      final repo = _repo(subject: _subjectNoFiles);
      await pumpShell(tester, repo);
      expect(fileTitled('b1'), findsOneWidget);
    });

    testWidgets('cause 4: a late features.files flip turns the tab on', (
      tester,
    ) async {
      final repo = _repo();
      repo.appConfigData = const AppConfigData(filesEnabled: true);
      var now = DateTime.utc(2026, 10, 12, 9);
      final appConfig = AppConfigProvider(
        repository: repo,
        versionReader: () async => '1.0.0',
        clock: () => now,
      )..setForTesting(const AppConfigData());
      await pumpShell(tester, repo, appConfig: appConfig);
      expect(find.text(l10n.ebookComingSoon), findsOneWidget);

      // The owner turns files on; the app-config copy expires (5 min TTL).
      now = now.add(const Duration(minutes: 6));
      clock.advance(const Duration(minutes: 6));
      await tapTab(tester, l10n.navHome);
      await tapTab(tester, l10n.navNotes);

      expect(find.text(l10n.ebookComingSoon), findsNothing);
      expect(fileTitled('b1'), findsOneWidget);
    });

    testWidgets('cause 4: the tab rebuilds when the flag changes', (
      tester,
    ) async {
      final repo = _repo();
      final appConfig = AppConfigProvider(versionReader: () async => '1.0.0')
        ..setForTesting(const AppConfigData());
      await pumpShell(tester, repo, appConfig: appConfig);
      expect(find.text(l10n.ebookComingSoon), findsOneWidget);
      appConfig.setForTesting(const AppConfigData(filesEnabled: true));
      await tester.pumpAndSettle();
      expect(fileTitled('b1'), findsOneWidget);
    });

    testWidgets('background refresh keeps the files on screen + indicator', (
      tester,
    ) async {
      final repo = _repo();
      await pumpShell(tester, repo);
      _adminAddsFile(repo);
      final gate = Completer<void>();
      repo.detailGate = gate.future;
      await tapTab(tester, l10n.navHome);
      clock.advance(const Duration(seconds: 31));
      // The bar animates while the refresh is held: pump, never settle.
      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.text(upper(l10n.navNotesAndBooks)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Cached first: the known file stays, a light indicator shows.
      expect(fileTitled('b1'), findsOneWidget);
      expect(find.byType(FileDownloadTile), findsOneWidget);
      expect(find.byKey(const ValueKey('refreshing_bar')), findsOneWidget);

      gate.complete();
      repo.detailGate = null;
      await tester.pumpAndSettle();
      expect(fileTitled('n2'), findsOneWidget);
      expect(find.byKey(const ValueKey('refreshing_bar')), findsNothing);
    });

    testWidgets('offline background refresh keeps the files on screen', (
      tester,
    ) async {
      final repo = _repo();
      await pumpShell(tester, repo);
      repo.levelsError = Exception('offline');
      repo.detailError = Exception('offline');
      await tapTab(tester, l10n.navHome);
      clock.advance(const Duration(seconds: 31));
      await tapTab(tester, l10n.navNotesAndBooks);
      // The global offline banner shows; the library is not blanked.
      expect(find.text(l10n.offlineBanner), findsOneWidget);
      expect(find.text(l10n.navNotesAndBooks), findsWidgets);
    });

    testWidgets('pull-to-refresh still refetches at once', (tester) async {
      final repo = _repo();
      await pumpShell(tester, repo);
      _adminAddsFile(repo);
      final indicator = tester.widget<RefreshIndicator>(
        find.ancestor(
          of: fileTitled('b1'),
          matching: find.byType(RefreshIndicator),
        ),
      );
      await indicator.onRefresh();
      await tester.pumpAndSettle();
      expect(fileTitled('n2'), findsOneWidget);
    });
  });

  group('Home and Courses freshness [$name]', () {
    testWidgets('Home refetches the catalog when it becomes visible again', (
      tester,
    ) async {
      final repo = _repo();
      await pumpShell(tester, repo, initialTab: 0);
      final calls = repo.levelsCalls;
      await tapTab(tester, l10n.navSettings);
      clock.advance(const Duration(seconds: 31));
      await tapTab(tester, l10n.navHome);
      expect(repo.levelsCalls, greaterThan(calls));
    });

    testWidgets('Courses refetches the catalog on app resume', (tester) async {
      final repo = _repo();
      await pumpShell(tester, repo, initialTab: 1);
      final calls = repo.levelsCalls;
      clock.advance(const Duration(seconds: 31));
      await _resume(tester);
      expect(repo.levelsCalls, greaterThan(calls));
    });

    testWidgets('a background catalog refresh never blanks Home', (
      tester,
    ) async {
      final repo = _repo();
      final catalog = await pumpShell(tester, repo, initialTab: 0);
      expect(catalog.isReady, isTrue);
      final reload = catalog.reload();
      // While the refresh runs the catalog stays ready (cached first).
      expect(catalog.isReady, isTrue);
      expect(catalog.isRefreshing, isTrue);
      await reload;
      expect(catalog.isRefreshing, isFalse);
    });
  });

  group('Notifications freshness [$name]', () {
    testWidgets('the list refetches on app resume, keeps items on failure', (
      tester,
    ) async {
      final repo = _MutableNotifRepo([_notif('a', 'First')]);
      final provider = NotificationsProvider(repository: repo)
        ..attachRemote(repo);
      await provider.loadRemote();
      await pumpScreen(
        tester,
        locale,
        const NotificationsScreen(),
        notifications: provider,
      );
      expect(find.text('First'), findsOneWidget);

      repo.items = [_notif('b', 'Second'), _notif('a', 'First')];
      clock.advance(const Duration(seconds: 31));
      await _resume(tester);
      expect(find.text('Second'), findsOneWidget);

      repo.error = Exception('offline');
      clock.advance(const Duration(seconds: 31));
      await _resume(tester);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('First'), findsOneWidget);
    });
  });
}
