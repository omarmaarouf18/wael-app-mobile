import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/models/academy_catalog.dart';
import 'package:wael_app/player/player_engine.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/screens/video_player_screen.dart';
import 'package:wael_app/services/secure_screen.dart';

import 'academy_fakes.dart';
import 'player_fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

// iOS screen-capture cover (owner decision 2026-10-12: recording protection
// covers iOS too). A fake native side answers `isCaptured` on the method
// channel and pushes the state on the event channel, the way
// AppDelegate.swift does.

const _args = VideoPlayerArgs(
  videoId: 'v1',
  subjectId: 'd1',
  title: 'Lesson one',
);

/// The fake iOS side of `com.wael.app/secure_screen` (+ `/capture`).
class _FakeIosChannel {
  _FakeIosChannel({this.captured = false, this.missing = false});

  bool captured;

  /// No native handler at all (MissingPluginException).
  final bool missing;
  final List<String> calls = [];
  MockStreamHandlerEventSink? _sink;

  static const method = MethodChannel(SecureScreen.channelName);
  static const events = EventChannel(SecureScreen.captureChannelName);

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    if (missing) {
      // What an app without the native side sees: no plugin answers.
      messenger.setMockMethodCallHandler(method, (call) async {
        calls.add(call.method);
        throw MissingPluginException();
      });
      return;
    }
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call.method);
      if (call.method == 'isCaptured') return captured;
      return null;
    });
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          _sink = sink;
          sink.success(captured);
        },
        onCancel: (_) => _sink = null,
      ),
    );
  }

  /// The student starts or stops a recording / mirroring.
  void set(bool value) {
    captured = value;
    _sink?.success(value);
  }

  void fail() => _sink?.error(code: 'boom');

  static void uninstall() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockStreamHandler(events, null);
  }
}

/// Platform-channel replies and events arrive a few microtask turns later.
Future<void> flush(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void main() {
  tearDown(_FakeIosChannel.uninstall);

  final (name, locale, _) = kLocales.first;
  final l10n = l10nFor(locale);

  Future<(FakePlayerEngine, FakeAcademyRepository)> open(
    WidgetTester tester,
    _FakeIosChannel channel,
  ) async {
    channel.install();
    final engine = FakePlayerEngine();
    final repo = fake();
    repo.playResults['v1'] = const VideoPlayback(
      videoId: 'v1',
      youtubeVideoId: 'dQw4w9WgXcQ',
    );
    final deps = PlayerDependencies(
      engineFactory: () => engine,
      secureScreen: SecureScreen(platform: TargetPlatform.iOS),
    );
    await pumpScreen(
      tester,
      locale,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push<Object?>(
            MaterialPageRoute<PlayerExit>(
              builder: (_) => const VideoPlayerScreen(args: _args),
            ),
          ),
          child: const Text('open'),
        ),
      ),
      auth: await signedInAuth(),
      extraProviders: [
        ChangeNotifierProvider<AcademyCatalogProvider>.value(
          value: AcademyCatalogProvider(repo),
        ),
        Provider<PlayerDependencies>.value(value: deps),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 50));
    await flush(tester);
    return (engine, repo);
  }

  Finder cover() => find.byKey(const ValueKey('capture_cover'));

  Future<void> resume(WidgetTester tester) async {
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('iOS capture cover [$name]', () {
    testWidgets('capture on before play: cover, nothing loads or plays', (
      tester,
    ) async {
      final channel = _FakeIosChannel(captured: true);
      final (engine, repo) = await open(tester, channel);

      expect(cover(), findsOneWidget);
      expect(find.text(l10n.playerCaptureBlocked), findsOneWidget);
      expect(engine.loadedIds, isEmpty);
      expect(engine.calls, isNot(contains('play')));
      expect(repo.playCalls, isEmpty);
      expect(channel.calls, containsAll(['enable', 'isCaptured']));
    });

    testWidgets('capture stops before play: the student taps play', (
      tester,
    ) async {
      final channel = _FakeIosChannel(captured: true);
      final (engine, _) = await open(tester, channel);
      channel.set(false);
      await flush(tester);

      expect(cover(), findsNothing);
      // No auto-start: nothing loads until the student taps play.
      expect(engine.loadedIds, isEmpty);
      await tester.tap(find.byKey(const ValueKey('capture_play')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(engine.loadedIds, ['dQw4w9WgXcQ']);
    });

    testWidgets('capture starts mid-play: pause, cover, play blocked', (
      tester,
    ) async {
      final channel = _FakeIosChannel();
      final (engine, _) = await open(tester, channel);
      engine.emit(const PlayerSnapshot(phase: PlayerPhase.playing));
      await tester.pump();
      expect(cover(), findsNothing);

      channel.set(true);
      await flush(tester);
      expect(cover(), findsOneWidget);
      expect(find.text(l10n.playerCaptureBlocked), findsOneWidget);
      expect(engine.calls.last, 'pause');

      // The embed reports playing anyway (e.g. a media key): paused again.
      engine.calls.clear();
      engine.emit(const PlayerSnapshot(phase: PlayerPhase.playing));
      await tester.pump();
      expect(engine.calls, contains('pause'));

      // The cover takes every tap: the play control cannot be reached.
      engine.calls.clear();
      await tester.tap(cover(), warnIfMissed: false);
      await tester.pump();
      expect(engine.calls, isNot(contains('play')));
    });

    testWidgets('capture stops: cover removed, no auto-resume', (tester) async {
      final channel = _FakeIosChannel();
      final (engine, _) = await open(tester, channel);
      engine.emit(const PlayerSnapshot(phase: PlayerPhase.playing));
      await tester.pump();
      channel.set(true);
      await flush(tester);
      engine.emit(const PlayerSnapshot(phase: PlayerPhase.paused));
      await tester.pump();
      engine.calls.clear();

      channel.set(false);
      await flush(tester);
      expect(cover(), findsNothing);
      expect(engine.calls, isNot(contains('play')));
    });

    testWidgets('a capture stream error counts as captured (fail closed)', (
      tester,
    ) async {
      final channel = _FakeIosChannel();
      final (engine, _) = await open(tester, channel);
      engine.emit(const PlayerSnapshot(phase: PlayerPhase.playing));
      await tester.pump();
      channel.fail();
      await flush(tester);
      expect(cover(), findsOneWidget);
      expect(engine.calls, contains('pause'));
    });

    testWidgets('channel missing: the player refuses to play', (tester) async {
      final channel = _FakeIosChannel(missing: true);
      final (engine, repo) = await open(tester, channel);
      expect(find.text(l10n.playerNotSecure), findsOneWidget);
      expect(engine.loadedIds, isEmpty);
      expect(repo.playCalls, isEmpty);
    });

    testWidgets('app resume re-checks: capture found on resume covers', (
      tester,
    ) async {
      final channel = _FakeIosChannel();
      final (engine, _) = await open(tester, channel);
      engine.emit(const PlayerSnapshot(phase: PlayerPhase.playing));
      await tester.pump();
      // Recording started while the app was in the background and the
      // change event was missed: only the resume check sees it.
      channel.captured = true;
      final before = channel.calls.where((c) => c == 'isCaptured').length;
      await resume(tester);
      expect(
        channel.calls.where((c) => c == 'isCaptured').length,
        greaterThan(before),
      );
      expect(cover(), findsOneWidget);
    });

    testWidgets('the cover spans the whole video area', (tester) async {
      final channel = _FakeIosChannel();
      final (engine, _) = await open(tester, channel);
      engine.emit(const PlayerSnapshot(phase: PlayerPhase.playing));
      await tester.pump();
      channel.set(true);
      await flush(tester);
      final coverBox = tester.getRect(cover());
      final videoBox = tester.getRect(find.byKey(const Key('fake-video')));
      expect(coverBox.contains(videoBox.topLeft), isTrue);
      expect(
        coverBox.contains(videoBox.bottomRight - const Offset(1, 1)),
        isTrue,
      );
    });
  });

  group('Android path unchanged [$name]', () {
    testWidgets('Android never asks for the capture state', (tester) async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_FakeIosChannel.method, (call) async {
            calls.add(call.method);
            return null;
          });
      final secure = SecureScreen(platform: TargetPlatform.android);
      expect(await secure.isCaptured(), isFalse);
      expect(await secure.captureChanges().isEmpty, isTrue);
      await secure.enable();
      expect(calls, ['enable']);
    });
  });
}
