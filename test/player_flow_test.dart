import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/models/academy_catalog.dart';
import 'package:wael_app/player/player_engine.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/ebook_provider.dart';
import 'package:wael_app/providers/home_provider.dart';
import 'package:wael_app/screens/course_detail_screen.dart';
import 'package:wael_app/screens/video_player_screen.dart';
import 'package:wael_app/widgets/catalog_video_tile.dart';

import 'academy_fakes.dart';
import 'player_fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

const _ytId = 'dQw4w9WgXcQ';

/// The subject screen with the real `/video-player` route, a fake player
/// engine and a fake Android channel: the flow a student takes.
Future<void> _pumpSubject(
  WidgetTester tester,
  Locale locale, {
  required FakeAcademyRepository repo,
  required FakePlayerEngine engine,
  required FakeSecureScreen secure,
}) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final catalog = AcademyCatalogProvider(repo);
  final auth = await signedInAuth();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider<AcademyCatalogProvider>.value(value: catalog),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => EBookProvider()),
        Provider<PlayerDependencies>.value(
          value: PlayerDependencies(
            engineFactory: () => engine,
            secureScreen: secure,
          ),
        ),
      ],
      child: localizedApp(
        locale,
        const CourseDetailScreen(courseId: 'd1'),
        routes: {
          '/video-player': (ctx) => VideoPlayerScreen(
            args: ModalRoute.of(ctx)!.settings.arguments! as VideoPlayerArgs,
          ),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (name, locale, _) in kLocales) {
    final l10n = l10nFor(locale);
    final isArabic = locale.languageCode == 'ar';

    FakeAcademyRepository repoWith({bool playable = true}) {
      final repo = fake();
      repo.detailJson['d1'] = detailBody(
        owned: playable,
        videos: [
          videoBody('v1', 1, playable: playable),
          videoBody('v2', 2),
        ],
      );
      return repo;
    }

    CatalogVideoTile tile(WidgetTester tester, int i) =>
        tester.widget<CatalogVideoTile>(find.byType(CatalogVideoTile).at(i));

    group('video tile flow [$name]', () {
      testWidgets('locked tile: says so, calls nothing, opens nothing', (
        tester,
      ) async {
        final repo = repoWith();
        final engine = FakePlayerEngine();
        final secure = FakeSecureScreen();
        await _pumpSubject(
          tester,
          locale,
          repo: repo,
          engine: engine,
          secure: secure,
        );

        expect(tile(tester, 1).locked, isTrue);
        await tester.tap(find.byType(CatalogVideoTile).at(1));
        await tester.pump();

        expect(find.text(ErrorMessages.courseLocked(isArabic)), findsOneWidget);
        expect(repo.playCalls, isEmpty);
        expect(engine.loadedIds, isEmpty);
        expect(secure.log, isEmpty);
        expect(find.byType(VideoPlayerScreen), findsNothing);
      });

      testWidgets('unlocked tile: tapping calls play and starts the player', (
        tester,
      ) async {
        final repo = repoWith()
          ..playResults['v1'] = VideoPlayback(
            videoId: 'v1',
            youtubeVideoId: _ytId,
          );
        final engine = FakePlayerEngine();
        final secure = FakeSecureScreen();
        await _pumpSubject(
          tester,
          locale,
          repo: repo,
          engine: engine,
          secure: secure,
        );

        expect(tile(tester, 0).locked, isFalse);
        await tester.tap(find.byType(CatalogVideoTile).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 100));

        expect(repo.playCalls, ['v1']);
        expect(engine.loadedIds, [_ytId]);
        expect(secure.enabled, isTrue);
        expect(find.byType(VideoPlayerScreen), findsOneWidget);

        // Back to the subject: everything released, tile still unlocked.
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(VideoPlayerScreen), findsNothing);
        expect(secure.enabled, isFalse);
        expect(engine.disposed, isTrue);
        expect(tile(tester, 0).locked, isFalse);
        expect(find.text(ErrorMessages.courseLocked(isArabic)), findsNothing);
      });

      testWidgets(
        '404 from the server: the player closes and the tile is locked',
        (tester) async {
          final repo = repoWith(); // playable in the detail, but play says 404
          final engine = FakePlayerEngine();
          final secure = FakeSecureScreen();
          await _pumpSubject(
            tester,
            locale,
            repo: repo,
            engine: engine,
            secure: secure,
          );
          expect(tile(tester, 0).locked, isFalse);
          final detailCallsBefore = repo.detailCalls;

          await tester.tap(find.byType(CatalogVideoTile).first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();

          expect(repo.playCalls, ['v1']);
          expect(engine.loadedIds, isEmpty);
          expect(find.byType(VideoPlayerScreen), findsNothing);
          expect(secure.enabled, isFalse);
          // Back on the subject, the tile is locked at once ...
          expect(tile(tester, 0).locked, isTrue);
          expect(
            find.text(ErrorMessages.courseLocked(isArabic)),
            findsOneWidget,
          );
          // ... and the subject is refetched so the server's flags win.
          expect(repo.detailCalls, greaterThan(detailCallsBefore));
          // Tapping it now only explains; it does not ask the server again.
          await tester.tap(find.byType(CatalogVideoTile).first);
          await tester.pump();
          expect(repo.playCalls, ['v1']);
        },
      );

      testWidgets('the id is in no widget text of either screen', (
        tester,
      ) async {
        final repo = repoWith()
          ..playResults['v1'] = VideoPlayback(
            videoId: 'v1',
            youtubeVideoId: _ytId,
          );
        final engine = FakePlayerEngine();
        await _pumpSubject(
          tester,
          locale,
          repo: repo,
          engine: engine,
          secure: FakeSecureScreen(),
        );
        await tester.tap(find.byType(CatalogVideoTile).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(engine.loadedIds, [_ytId]);
        expect(find.textContaining(_ytId, findRichText: true), findsNothing);
        expect(find.text(l10n.retry), findsNothing);
      });
    });
  }
}
