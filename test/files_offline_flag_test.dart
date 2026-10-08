import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/core/app_config_cache.dart';
import 'package:wael_app/models/academy_catalog.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/providers/files_provider.dart';
import 'package:wael_app/screens/ebook_screen.dart';

import 'academy_fakes.dart';
import 'files_fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

/// F2 (owner follow-up 2026-10-08): the last `features.files` the server
/// sent is persisted on disk and used on a cold start when app-config is
/// unreachable; an explicit server `false` overrides it; a fresh install
/// offline is off.

const owned = AcademySubject(
  id: 'sub1',
  levelKey: 'bachelor-y1',
  term: 'first',
  title: LocalizedText(ar: 'القانون المدني', en: 'Civil Law'),
  description: LocalizedText(),
  owned: true,
  counts: SubjectCounts(books: 1),
);

const book = AcademyFile(
  id: 'b1',
  kind: 'book',
  title: LocalizedText(ar: 'كتاب المادة', en: 'Course book'),
  sizeBytes: 2048,
);

const _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// Stands in for the platform keystore: survives new cache instances (a
/// cold start) for the duration of one test.
void useFakeDisk(Map<String, String> disk) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureChannel, (call) async {
        final args = (call.arguments as Map).cast<String, Object?>();
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return disk[key];
          case 'write':
            disk[key!] = args['value'] as String;
            return null;
          case 'delete':
            disk.remove(key);
            return null;
        }
        return null;
      });
}

/// Back to the suite default (no plugin; see flutter_test_config.dart).
void restoreNoPlugin() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureChannel, (call) async {
        throw MissingPluginException('no secure storage in tests');
      });
}

class ConfigRepo extends FakeAcademyRepository {
  ConfigRepo({this.answer, this.error, this.gate})
    : super(levelList: [level('bachelor-y1', 'bachelor', 1)]);

  final AppConfigData? answer;
  final Object? error;
  final Future<void>? gate;

  @override
  Future<AppConfigData> appConfig() async {
    if (gate != null) await gate;
    if (error != null) throw error!;
    return answer!;
  }
}

AppConfigProvider coldStart(ConfigRepo repo, {AppConfigCache? cache}) =>
    AppConfigProvider(
      repository: repo,
      cache: cache ?? SecureAppConfigCache(),
      versionReader: () async => '1.0.0',
      // Days after the last fetch: the copy is far past its 5-minute
      // freshness window.
      clock: () => DateTime.now().add(const Duration(days: 3)),
    );

void main() {
  late Map<String, String> disk;

  setUp(() {
    disk = {};
    useFakeDisk(disk);
  });
  tearDown(restoreNoPlugin);

  /// A previous run that reached the server and got [files].
  Future<void> previousRun(bool files) async {
    final online = AppConfigProvider(
      repository: ConfigRepo(answer: AppConfigData(filesEnabled: files)),
      cache: SecureAppConfigCache(),
      versionReader: () async => '1.0.0',
    );
    await online.load();
    expect(online.filesEnabled, files);
  }

  test('the server value is persisted on disk', () async {
    await previousRun(true);
    expect(disk.values.single, contains('"files":true'));
  });

  test('cold start offline with persisted true: on', () async {
    await previousRun(true);
    final p = coldStart(ConfigRepo(error: const SocketException('down')));
    await p.load();
    expect(p.filesEnabled, isTrue);
  });

  test('cold start on a hanging network: persisted value shown before the '
      'fetch gives up', () async {
    await previousRun(true);
    final gate = Completer<void>();
    final p = coldStart(
      ConfigRepo(error: const SocketException('down'), gate: gate.future),
    );
    var notifiedOn = false;
    p.addListener(() => notifiedOn = notifiedOn || p.filesEnabled);
    final load = p.load();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(notifiedOn, isTrue);
    gate.complete();
    await load;
    expect(p.filesEnabled, isTrue);
  });

  test(
    'an explicit server false overrides persisted true, and persists',
    () async {
      await previousRun(true);
      final p = coldStart(
        ConfigRepo(answer: const AppConfigData(filesEnabled: false)),
      );
      await p.load();
      expect(p.filesEnabled, isFalse);
      // The next offline cold start keeps it off.
      final offline = coldStart(ConfigRepo(error: const SocketException('x')));
      await offline.load();
      expect(offline.filesEnabled, isFalse);
    },
  );

  test('a reachable server that omits features turns it off', () async {
    await previousRun(true);
    final p = coldStart(
      ConfigRepo(answer: AppConfigData.fromJson(const {'terms_url': ''})),
    );
    await p.load();
    expect(p.filesEnabled, isFalse);
  });

  test('fresh install offline: off', () async {
    final p = coldStart(ConfigRepo(error: const SocketException('down')));
    await p.load();
    expect(p.filesEnabled, isFalse);
    expect(disk, isEmpty);
  });

  for (final (name, locale, _) in kLocales) {
    final l10n = l10nFor(locale);
    final ar = locale.languageCode == 'ar';

    Future<FakeOpener> pumpNotes(
      WidgetTester tester,
      AppConfigProvider config,
    ) async {
      final store = FakeFileDownloadStore()..seed(owned, book);
      final opener = FakeOpener();
      final files = FilesProvider(store: store, opener: opener);
      await files.bindUser('pending'); // offline: user id not known yet
      // Catalog unreachable too (whole app offline, no cached catalog).
      final catalog = AcademyCatalogProvider(
        fake()..levelsError = const SocketException('down'),
      );
      files.attachCatalog(catalog);
      await pumpScreen(
        tester,
        locale,
        const EbookScreen(),
        appConfig: config,
        extraProviders: [
          ChangeNotifierProvider<AcademyCatalogProvider>.value(value: catalog),
          ChangeNotifierProvider<FilesProvider>.value(value: files),
        ],
      );
      return opener;
    }

    testWidgets('[$name] cold start offline, persisted true: downloaded '
        'files list, open and share', (tester) async {
      late AppConfigProvider config;
      await tester.runAsync(() async {
        await previousRun(true);
        config = coldStart(ConfigRepo(error: const SocketException('x')));
        await config.load();
      });
      final opener = await pumpNotes(tester, config);
      expect(find.text(l10n.navNotesAndBooks), findsOneWidget);
      expect(find.text(ar ? 'كتاب المادة' : 'Course book'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open-b1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('share-b1')));
      await tester.pumpAndSettle();
      expect(opener.opened, hasLength(1));
      expect(opener.shared, hasLength(1));
    });

    testWidgets('[$name] server false over persisted true: coming soon', (
      tester,
    ) async {
      late AppConfigProvider config;
      await tester.runAsync(() async {
        await previousRun(true);
        config = coldStart(
          ConfigRepo(answer: const AppConfigData(filesEnabled: false)),
        );
        await config.load();
      });
      await pumpNotes(tester, config);
      expect(find.text(l10n.ebookComingSoon), findsOneWidget);
      expect(find.text(ar ? 'كتاب المادة' : 'Course book'), findsNothing);
    });

    testWidgets('[$name] fresh install offline: coming soon', (tester) async {
      late AppConfigProvider config;
      await tester.runAsync(() async {
        config = coldStart(ConfigRepo(error: const SocketException('x')));
        await config.load();
      });
      await pumpNotes(tester, config);
      expect(find.text(l10n.ebookComingSoon), findsOneWidget);
      expect(find.text(l10n.navNotesAndBooks), findsNothing);
    });
  }
}
