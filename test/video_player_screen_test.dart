import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, SocketException;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:provider/provider.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/core/secure_store.dart';
import 'package:wael_app/debug/diagnostics_tracker.dart';
import 'package:wael_app/models/academy_catalog.dart';
import 'package:wael_app/player/player_engine.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/auth_provider.dart';
import 'package:wael_app/repositories/academy_repository.dart';
import 'package:wael_app/screens/video_player_screen.dart';
import 'package:wael_app/widgets/moving_watermark.dart';
import 'package:wael_app/widgets/player_controls.dart';
import 'package:wael_app/widgets/protected_video_surface.dart';
import 'package:wael_app/widgets/themed_error_banner.dart';
import 'package:wael_app/widgets/themed_loading_indicator.dart';

import 'academy_fakes.dart';
import 'player_fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

const _ytId = 'dQw4w9WgXcQ';
const _args = VideoPlayerArgs(
  videoId: 'v1',
  title: 'Lesson one',
  description: 'About it',
);

VideoPlayback _playback([String id = _ytId]) =>
    VideoPlayback(videoId: 'v1', youtubeVideoId: id);

/// Everything a player test needs, wired the way main.dart wires the app.
class _Rig {
  _Rig({
    FakeAcademyRepository? repo,
    FakePlayerEngine? engine,
    FakeSecureScreen? secure,
  }) : repo = repo ?? fake(),
       engine = engine ?? FakePlayerEngine(),
       secure = secure ?? FakeSecureScreen() {
    this.repo.playResults['v1'] = _playback();
    catalog = AcademyCatalogProvider(this.repo);
    deps = PlayerDependencies(
      engineFactory: () => this.engine,
      secureScreen: this.secure,
    );
  }

  final FakeAcademyRepository repo;
  final FakePlayerEngine engine;
  final FakeSecureScreen secure;
  late final AcademyCatalogProvider catalog;
  late final PlayerDependencies deps;
  Object? exit;
  bool popped = false;

  /// Opens the player from a button, the way the subject screen does, and
  /// records how it ended.
  Future<void> pump(
    WidgetTester tester,
    Locale locale, {
    AuthProvider? auth,
    Size size = const Size(390, 844),
  }) async {
    await pumpScreen(
      tester,
      locale,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            exit = await Navigator.of(context).push<Object?>(
              MaterialPageRoute<PlayerExit>(
                builder: (_) => const VideoPlayerScreen(args: _args),
              ),
            );
            popped = true;
          },
          child: const Text('open'),
        ),
      ),
      auth: auth ?? await signedInAuth(),
      extraProviders: [
        ChangeNotifierProvider<AcademyCatalogProvider>.value(value: catalog),
        Provider<PlayerDependencies>.value(value: deps),
      ],
      size: size,
    );
    await tester.tap(find.text('open'));
    // The loading spinner never settles; a few frames are enough.
    await tester.pump();
    // Let the route transition finish (the spinner never settles).
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Every string a user, a screen reader or a test could read off the tree.
List<String> _allVisibleStrings(WidgetTester tester) {
  final out = <String>[];
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    final data = t.data ?? t.textSpan?.toPlainText();
    if (data != null) out.add(data);
  }
  for (final t in tester.widgetList<EditableText>(find.byType(EditableText))) {
    out.add(t.controller.text);
  }
  final semantics = tester.binding.rootPipelineOwner.semanticsOwner;
  if (semantics != null) {
    void walk(SemanticsNode node) {
      out
        ..add(node.label)
        ..add(node.value)
        ..add(node.hint)
        ..add(node.tooltip);
      node.visitChildren((c) {
        walk(c);
        return true;
      });
    }

    final root = semantics.rootSemanticsNode;
    if (root != null) walk(root);
  }
  return out;
}

void main() {
  late List<MethodCall> systemCalls;

  setUp(() {
    systemCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          systemCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  for (final (name, locale, direction) in kLocales) {
    final l10n = l10nFor(locale);
    final isArabic = locale.languageCode == 'ar';

    group('VideoPlayerScreen [$name]', () {
      testWidgets('opens: secure first, then play call, then the engine', (
        tester,
      ) async {
        final rig = _Rig();
        await rig.pump(tester, locale);

        expect(rig.secure.log, ['enable']);
        expect(rig.repo.playCalls, ['v1']);
        expect(rig.engine.loadedIds, [_ytId]);
        expect(find.byType(VideoPlayerScreen), findsOneWidget);
        expect(find.byType(ProtectedVideoSurface), findsOneWidget);
        expect(find.byKey(const Key('fake-video')), findsOneWidget);
        expect(find.text('Lesson one'), findsWidgets);
        expect(find.text('About it'), findsOneWidget);
      });

      testWidgets('shows the starting state before the answer arrives', (
        tester,
      ) async {
        final rig = _Rig();
        final gate = Completer<VideoPlayback>();
        rig.repo.playResults.remove('v1');
        final slow = _GatedRepository(rig.repo, gate.future);
        final catalog = AcademyCatalogProvider(slow);
        final deps = PlayerDependencies(
          engineFactory: () => rig.engine,
          secureScreen: rig.secure,
        );
        await pumpScreen(
          tester,
          locale,
          const VideoPlayerScreen(args: _args),
          auth: await signedInAuth(),
          extraProviders: [
            ChangeNotifierProvider<AcademyCatalogProvider>.value(
              value: catalog,
            ),
            Provider<PlayerDependencies>.value(value: deps),
          ],
          settle: false,
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(ThemedLoadingIndicator), findsOneWidget);
        expect(find.text(l10n.playerStarting), findsOneWidget);
        expect(rig.engine.loadedIds, isEmpty);
        gate.complete(_playback());
        await tester.pump();
        await tester.pump();
        expect(rig.engine.loadedIds, [_ytId]);
      });

      testWidgets('leaving releases the engine, the id and FLAG_SECURE', (
        tester,
      ) async {
        final rig = _Rig();
        await rig.pump(tester, locale);
        expect(rig.secure.enabled, isTrue);

        // The spinner never settles, so pump frames instead.
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(rig.popped, isTrue);
        expect(rig.exit, isNull);
        expect(rig.engine.disposed, isTrue);
        expect(rig.secure.enabled, isFalse);
        expect(rig.secure.log, ['enable', 'disable']);
        // System UI and orientation go back to normal.
        expect(
          systemCalls.map((c) => c.method),
          contains('SystemChrome.setPreferredOrientations'),
        );
      });

      testWidgets('404 on open: closes as locked, nothing was played', (
        tester,
      ) async {
        final rig = _Rig();
        rig.repo.playResults['v1'] = ApiException(
          statusCode: 404,
          message: 'x',
        );
        await rig.pump(tester, locale);
        await tester.pumpAndSettle();

        expect(rig.popped, isTrue);
        expect(rig.exit, PlayerExit.locked);
        expect(rig.engine.loadedIds, isEmpty);
        expect(rig.secure.enabled, isFalse);
        expect(find.byType(VideoPlayerScreen), findsNothing);
      });

      testWidgets('a network failure stays open with a banner; retry plays', (
        tester,
      ) async {
        final rig = _Rig();
        rig.repo.playResults['v1'] = const SocketException('down');
        await rig.pump(tester, locale);

        expect(find.byType(ThemedErrorBanner), findsOneWidget);
        expect(find.text(ErrorMessages.networkError(isArabic)), findsOneWidget);
        expect(rig.engine.loadedIds, isEmpty);
        await tester.pump(const Duration(minutes: 1));
        expect(find.byType(ThemedErrorBanner), findsOneWidget);

        rig.repo.playResults['v1'] = _playback();
        await tester.tap(find.text(l10n.retry));
        await tester.pump();
        await tester.pump();
        expect(rig.repo.playCalls, ['v1', 'v1']);
        expect(rig.engine.loadedIds, [_ytId]);
        expect(find.byType(ThemedErrorBanner), findsNothing);
      });

      testWidgets('a 5xx also stays open and does not lock', (tester) async {
        final rig = _Rig();
        rig.repo.playResults['v1'] = ApiException(
          statusCode: 503,
          message: 'x',
        );
        await rig.pump(tester, locale);
        expect(rig.popped, isFalse);
        expect(
          find.text(ErrorMessages.serviceUnavailable(isArabic)),
          findsOneWidget,
        );
      });

      testWidgets('no identity: refuses to play and asks nothing', (
        tester,
      ) async {
        final rig = _Rig();
        await rig.pump(tester, locale, auth: makeAuth());
        expect(find.text(l10n.playerNoIdentity), findsOneWidget);
        expect(rig.repo.playCalls, isEmpty);
        expect(rig.engine.loadedIds, isEmpty);
        expect(find.byType(MovingWatermark), findsNothing);
        // Not retryable: it is the account that must be fixed.
        expect(find.text(l10n.retry), findsNothing);
      });

      testWidgets('a device that cannot be secured does not play', (
        tester,
      ) async {
        final rig = _Rig(secure: FakeSecureScreen(enableError: true));
        await rig.pump(tester, locale);
        expect(find.text(l10n.playerNotSecure), findsOneWidget);
        expect(rig.repo.playCalls, isEmpty);
        expect(rig.engine.loadedIds, isEmpty);
      });

      testWidgets('a platform without a player shows an error', (tester) async {
        final rig = _Rig(engine: FakePlayerEngine(failOnLoad: true));
        await rig.pump(tester, locale);
        expect(find.text(l10n.playerUnavailable), findsOneWidget);
        expect(rig.popped, isFalse);
      });
    });

    group('resume [$name]', () {
      testWidgets('background pauses; resume asks again and keeps playing', (
        tester,
      ) async {
        final rig = _Rig();
        await rig.pump(tester, locale);
        expect(rig.repo.playCalls, ['v1']);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(rig.engine.calls, contains('pause'));

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump();
        expect(rig.repo.playCalls, ['v1', 'v1']);
        expect(rig.popped, isFalse);
        expect(rig.secure.log.where((e) => e == 'enable').length, 2);
      });

      testWidgets('404 on resume closes the player as locked', (tester) async {
        final rig = _Rig();
        await rig.pump(tester, locale);
        rig.repo.playResults['v1'] = ApiException(
          statusCode: 404,
          message: 'x',
        );

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(rig.popped, isTrue);
        expect(rig.exit, PlayerExit.locked);
        expect(rig.engine.disposed, isTrue);
        expect(rig.secure.enabled, isFalse);
      });

      testWidgets('another failure on resume pauses and shows a banner', (
        tester,
      ) async {
        final rig = _Rig();
        await rig.pump(tester, locale);
        rig.repo.playResults['v1'] = const SocketException('down');
        rig.engine.calls.clear();

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump();

        expect(rig.popped, isFalse);
        expect(rig.engine.calls, contains('pause'));
        expect(find.byType(ThemedErrorBanner), findsOneWidget);

        rig.repo.playResults['v1'] = _playback();
        await tester.tap(find.text(l10n.retry));
        await tester.pump();
        await tester.pump();
        expect(find.byType(ThemedErrorBanner), findsNothing);
      });

      testWidgets('a replaced video (new id) is loaded on resume', (
        tester,
      ) async {
        final rig = _Rig();
        await rig.pump(tester, locale);
        rig.repo.playResults['v1'] = _playback('AAAAAAAAAAA');

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump();
        expect(rig.engine.loadedIds, [_ytId, 'AAAAAAAAAAA']);
      });
    });

    group('controls and full screen [$name]', () {
      testWidgets('tap toggles the controls; buttons drive the engine', (
        tester,
      ) async {
        final rig = _Rig();
        await rig.pump(tester, locale);
        rig.engine.emit(
          const PlayerSnapshot(
            phase: PlayerPhase.playing,
            position: Duration(seconds: 30),
            duration: Duration(minutes: 5),
          ),
        );
        await tester.pump();
        expect(find.byType(PlayerControls), findsOneWidget);
        expect(find.text('00:30'), findsOneWidget);
        expect(find.text('05:00'), findsOneWidget);

        // Controls hide on their own once playing, and a tap brings them back.
        await tester.pump(const Duration(seconds: 4));
        expect(find.byType(PlayerControls), findsNothing);
        await tester.tapAt(
          tester.getCenter(find.byKey(const Key('fake-video'))),
        );
        await tester.pump();
        expect(find.byType(PlayerControls), findsOneWidget);

        await tester.tap(find.byTooltip(l10n.rewind10));
        await tester.tap(find.byTooltip(l10n.forward10));
        await tester.tap(find.byTooltip(l10n.pauseLabel));
        expect(
          rig.engine.calls,
          containsAllInOrder(['seek:20', 'seek:40', 'pause']),
        );
      });

      testWidgets('paused video keeps its controls and play resumes it', (
        tester,
      ) async {
        final rig = _Rig();
        await rig.pump(tester, locale);
        rig.engine.emit(
          const PlayerSnapshot(
            phase: PlayerPhase.paused,
            duration: Duration(minutes: 1),
          ),
        );
        await tester.pump(const Duration(seconds: 5));
        expect(find.byType(PlayerControls), findsOneWidget);
        await tester.tap(find.byTooltip(l10n.playLabel));
        expect(rig.engine.calls.last, 'play');
      });

      testWidgets('full screen hides the header, keeps the watermark', (
        tester,
      ) async {
        final rig = _Rig();
        await rig.pump(tester, locale);
        expect(find.byType(AppBar), findsOneWidget);
        final text = 'Jane Doe · +201000000000';
        expect(find.text(text), findsOneWidget);

        await tester.tap(find.byTooltip(l10n.enterFullscreen));
        await tester.pump();
        expect(find.byType(AppBar), findsNothing);
        expect(find.text(text), findsOneWidget);
        expect(find.byType(MovingWatermark), findsOneWidget);
        expect(
          systemCalls
              .where((c) => c.method == 'SystemChrome.setEnabledSystemUIMode')
              .last
              .arguments,
          'SystemUiMode.immersiveSticky',
        );
        // The video fills the screen.
        final size = tester.getSize(find.byType(ProtectedVideoSurface));
        expect(size.width, 390);
        expect(size.height, closeTo(844, 1));

        await tester.tap(find.byTooltip(l10n.exitFullscreen));
        await tester.pump();
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.text(text), findsOneWidget);
        expect(
          systemCalls
              .where((c) => c.method == 'SystemChrome.setEnabledSystemUIMode')
              .last
              .arguments,
          'SystemUiMode.edgeToEdge',
        );
      });

      testWidgets('the same video surface survives full screen (no rebuild)', (
        tester,
      ) async {
        final rig = _Rig();
        await rig.pump(tester, locale);
        final before = tester.element(find.byKey(const Key('fake-video')));
        await tester.tap(find.byTooltip(l10n.enterFullscreen));
        await tester.pump();
        final after = tester.element(find.byKey(const Key('fake-video')));
        expect(identical(before, after), isTrue);
      });

      testWidgets('ended: opaque cover with replay hides suggestions', (
        tester,
      ) async {
        final rig = _Rig();
        await rig.pump(tester, locale);
        rig.engine.emit(
          const PlayerSnapshot(
            phase: PlayerPhase.ended,
            duration: Duration(minutes: 1),
          ),
        );
        await tester.pump();
        expect(find.byType(PlayerControls), findsNothing);
        expect(find.byTooltip(l10n.replayLabel), findsOneWidget);
        // The watermark is still on top.
        expect(find.byType(MovingWatermark), findsOneWidget);
        await tester.tap(find.byTooltip(l10n.replayLabel));
        await tester.pump();
        expect(rig.engine.calls, containsAllInOrder(['seek:0', 'play']));
      });

      testWidgets('layout mirrors ($direction): back button at the start', (
        tester,
      ) async {
        final rig = _Rig();
        await rig.pump(tester, locale);
        final back = tester.getCenter(find.byTooltip(l10n.back)).dx;
        expect(
          direction == TextDirection.ltr ? back < 100 : back > 290,
          isTrue,
        );
        // The time bar stays left to right, like every media player.
        rig.engine.emit(
          const PlayerSnapshot(
            phase: PlayerPhase.paused,
            position: Duration(seconds: 5),
            duration: Duration(minutes: 1),
          ),
        );
        await tester.pump();
        expect(
          tester.getCenter(find.text('00:05')).dx,
          lessThan(tester.getCenter(find.text('01:00')).dx),
        );
      });
    });

    group('watermark [$name]', () {
      testWidgets('shows name and phone, ignores touches, hidden from a11y', (
        tester,
      ) async {
        final rig = _Rig();
        await rig.pump(tester, locale);
        final mark = find.byType(MovingWatermark);
        expect(mark, findsOneWidget);
        expect(find.text('Jane Doe · +201000000000'), findsOneWidget);
        expect(
          find.descendant(of: mark, matching: find.byType(IgnorePointer)),
          findsWidgets,
        );
        expect(
          find.descendant(of: mark, matching: find.byType(ExcludeSemantics)),
          findsOneWidget,
        );
        // It is above the gesture layer: it is the last child of the surface.
        final stack = tester.widget<Stack>(
          find
              .descendant(
                of: find.byType(ProtectedVideoSurface),
                matching: find.byType(Stack),
              )
              .first,
        );
        expect(stack.children.last, isA<MovingWatermark>());
      });

      testWidgets('falls back to the email when the backend sent no name', (
        tester,
      ) async {
        final rig = _Rig();
        await rig.pump(
          tester,
          locale,
          auth: await signedInAuth(name: '', phone: ''),
        );
        expect(find.text('u@e.com'), findsOneWidget);
      });

      testWidgets('moves about every 20 seconds, never to the same spot', (
        tester,
      ) async {
        final rig = _Rig();
        await rig.pump(tester, locale);
        Alignment current() =>
            tester
                    .widget<AnimatedAlign>(
                      find.descendant(
                        of: find.byType(MovingWatermark),
                        matching: find.byType(AnimatedAlign),
                      ),
                    )
                    .alignment
                as Alignment;
        final seen = <Alignment>[current()];
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(seconds: 19));
          expect(current(), seen.last, reason: 'not before 20 s');
          await tester.pump(const Duration(seconds: 1));
          expect(current(), isNot(seen.last));
          seen.add(current());
        }
        expect(seen.toSet().length, greaterThan(2));
        for (final a in seen) {
          expect(MovingWatermark.positions.contains(a), isTrue, reason: '$a');
        }
      });

      testWidgets('a tap where the watermark is reaches the gesture layer', (
        tester,
      ) async {
        final rig = _Rig();
        await rig.pump(tester, locale);
        rig.engine.emit(
          const PlayerSnapshot(
            phase: PlayerPhase.playing,
            duration: Duration(minutes: 1),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));
        expect(find.byType(PlayerControls), findsNothing);
        // Tapping the watermark text toggles controls; it cannot be dismissed.
        await tester.tap(
          find.text('Jane Doe · +201000000000'),
          warnIfMissed: false,
        );
        await tester.pump();
        expect(find.byType(PlayerControls), findsOneWidget);
        expect(find.text('Jane Doe · +201000000000'), findsOneWidget);
      });
    });

    group('the YouTube id never leaks [$name]', () {
      testWidgets('not in any text, semantics label, route argument or log', (
        tester,
      ) async {
        final logged = <String>[];
        final oldDebugPrint = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) =>
            logged.add(message ?? '');

        final tokens = MemoryTokenStore();
        final semantics = tester.ensureSemantics();
        final rig = _Rig();
        await rig.pump(
          tester,
          locale,
          auth: await signedInAuth(tokens: tokens),
        );
        rig.engine.emit(
          const PlayerSnapshot(
            phase: PlayerPhase.playing,
            duration: Duration(minutes: 3),
          ),
        );
        await tester.pump();

        // It reached the engine (the only place it should be) ...
        expect(rig.engine.loadedIds, [_ytId]);
        // ... and nowhere a person or a test can read.
        expect(
          _allVisibleStrings(tester).where((s) => s.contains(_ytId)),
          isEmpty,
        );
        expect(find.textContaining(_ytId, findRichText: true), findsNothing);
        expect(find.bySemanticsLabel(RegExp(_ytId)), findsNothing);
        expect(logged.where((l) => l.contains(_ytId)), isEmpty);
        expect(
          rig.catalog.toString() + rig.engine.toString(),
          isNot(contains(_ytId)),
        );
        // The route that opened the player carried only the academy video id.
        expect(_args.videoId, isNot(contains(_ytId)));
        expect(_args.title + _args.description, isNot(contains(_ytId)));
        // Persisted storage holds the session tokens and nothing else.
        expect(await tokens.readAccessToken(), isNot(contains(_ytId)));
        expect(await tokens.readRefreshToken(), isNot(contains(_ytId)));
        semantics.dispose();
        // Restore before the test ends: the framework checks it first.
        debugPrint = oldDebugPrint;
      });

      testWidgets('not in the diagnostics log of API calls (real repository)', (
        tester,
      ) async {
        DiagnosticsTracker.instance.clear();
        final api = _recordingApi(_ytId);
        final catalog = AcademyCatalogProvider(HttpAcademyRepository(api));
        final rig = _Rig();
        final deps = PlayerDependencies(
          engineFactory: () => rig.engine,
          secureScreen: rig.secure,
        );
        await pumpScreen(
          tester,
          locale,
          const VideoPlayerScreen(args: _args),
          auth: await signedInAuth(),
          extraProviders: [
            ChangeNotifierProvider<AcademyCatalogProvider>.value(
              value: catalog,
            ),
            Provider<PlayerDependencies>.value(value: deps),
          ],
          settle: false,
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(rig.engine.loadedIds, [_ytId]);
        final calls = DiagnosticsTracker.instance.calls;
        expect(calls, isNotEmpty);
        for (final call in calls) {
          expect(call.path, isNot(contains(_ytId)));
          expect('$call ${call.path} ${call.method}', isNot(contains(_ytId)));
        }
        expect(calls.first.path, '/api/v1/academy/videos/v1/play');
      });
    });
  }

  group('static guards', () {
    test('the YouTube id is named only where it is handled', () {
      const allowed = {
        'lib/models/academy_catalog.dart',
        'lib/player/player_engine.dart',
        'lib/player/youtube_iframe_engine.dart',
        'lib/screens/video_player_screen.dart',
      };
      final offenders = <String>[];
      for (final f in _dartFiles('lib')) {
        if (_text(f).contains('youtubeVideoId') && !allowed.contains(f)) {
          offenders.add(f);
        }
      }
      expect(offenders, isEmpty);
    });

    test('no print, debugPrint, log or throw mentions the id', () {
      final offenders = <String>[];
      for (final f in _dartFiles('lib')) {
        final lines = _text(f).split('\n');
        for (var i = 0; i < lines.length; i++) {
          final l = lines[i];
          final touchesId =
              l.contains('youtubeVideoId') || l.contains('_youtubeId');
          final sink = RegExp(
            r'\b(print|debugPrint|log|developer\.log|throw|Text)\(',
          );
          if (touchesId && sink.hasMatch(l)) offenders.add('$f:${i + 1}');
        }
      }
      expect(offenders, isEmpty);
    });

    test('route names and arguments never take a YouTube id', () {
      final main = _text('lib/main.dart');
      expect(main.contains('youtubeVideoId'), isFalse);
      expect(main.contains('youtube_video_id'), isFalse);
      expect(
        _text('lib/screens/video_player_screen.dart'),
        contains('VideoPlayerArgs'),
      );
    });
  });
}

class _GatedRepository extends FakeAcademyRepository {
  _GatedRepository(FakeAcademyRepository base, this._gate)
    : super(levelList: base.levelList, subjectsByLevel: base.subjectsByLevel);

  final Future<VideoPlayback> _gate;

  @override
  Future<VideoPlayback> playVideo(String videoId) => _gate;
}

ApiClient _recordingApi(String youtubeId) {
  // A real ApiClient over a fake HTTP client, so the diagnostics tracker sees
  // the request the app really makes.
  return ApiClient(
    baseUrl: 'https://gateway.test',
    client: MockClient(
      (_) async => http.Response(
        jsonEncode({'video_id': 'v1', 'youtube_video_id': youtubeId}),
        200,
      ),
    ),
    accessTokenReader: () async => 'token',
  );
}

Iterable<String> _dartFiles(String dir) =>
    _list(dir).where((p) => p.endsWith('.dart'));

Iterable<String> _list(String dir) sync* {
  for (final e in Directory(dir).listSync(recursive: true)) {
    if (e is File) yield e.path.replaceAll('\\', '/');
  }
}

String _text(String path) => File(path).readAsStringSync();
