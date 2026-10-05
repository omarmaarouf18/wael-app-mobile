import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/player/player_engine.dart';
import 'package:wael_app/widgets/protected_video_surface.dart';

import 'widget_layer_harness.dart';

const _portrait = Size(390, 219.375); // 16:9 on a 390 wide phone
const _fullscreen = Size(844, 390); // landscape phone, full screen

const _idle = PlayerSnapshot();
const _playing = PlayerSnapshot(
  phase: PlayerPhase.playing,
  position: Duration(seconds: 30),
  duration: Duration(minutes: 10),
);
const _paused = PlayerSnapshot(
  phase: PlayerPhase.paused,
  position: Duration(seconds: 30),
  duration: Duration(minutes: 10),
);

/// The surface at [size], with the video faked as an empty box.
Widget _surface(
  PlayerSnapshot snapshot, {
  Size size = _portrait,
  bool controlsVisible = false,
  ValueChanged<Duration>? onSeek,
}) {
  return Material(
    type: MaterialType.transparency,
    child: Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: ProtectedVideoSurface(
          video: const SizedBox.expand(key: Key('fake-video')),
          snapshot: snapshot,
          watermarkText: 'Jane Doe · +201000000000',
          controlsVisible: controlsVisible,
          isFullscreen: size == _fullscreen,
          onTap: () {},
          onPlayPause: () {},
          onSeek: onSeek ?? (_) {},
          onToggleFullscreen: () {},
          onReplay: () {},
        ),
      ),
    ),
  );
}

final _titleMask = find.byKey(ProtectedVideoSurface.titleMaskKey);

/// Moves to [snapshot] without remounting the surface, so `didUpdateWidget`
/// sees the transition exactly as it does on the player screen.
Future<void> _go(
  WidgetTester tester,
  Locale locale,
  PlayerSnapshot snapshot, {
  Size size = _portrait,
  bool controlsVisible = false,
  ValueChanged<Duration>? onSeek,
}) async {
  // Room for the 844 wide full-screen case (the default window is 800 wide).
  tester.view.physicalSize = const Size(900, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    localizedApp(
      locale,
      _surface(
        snapshot,
        size: size,
        controlsVisible: controlsVisible,
        onSeek: onSeek,
      ),
    ),
  );
  // Zero-length: lets the localizations finish loading on the first mount
  // without moving the clock the hold timer runs on.
  await tester.pump();
}

const _justUnderHold = Duration(milliseconds: 3900);
const _pastHold = Duration(milliseconds: 200);

void main() {
  for (final (name, locale, _) in kLocales) {
    group('ProtectedVideoSurface title mask [$name]', () {
      testWidgets('is shown while the video is not playing', (tester) async {
        await _go(tester, locale, _idle);
        expect(_titleMask, findsOneWidget);
        await _go(tester, locale, _paused);
        expect(_titleMask, findsOneWidget);
        // Not a timed state: still there a long time later.
        await tester.pump(const Duration(seconds: 30));
        expect(_titleMask, findsOneWidget);
      });

      testWidgets('stays for 4 seconds after play starts, then goes', (
        tester,
      ) async {
        await _go(tester, locale, _idle);
        await _go(tester, locale, _playing);
        expect(_titleMask, findsOneWidget);

        await tester.pump(_justUnderHold);
        expect(_titleMask, findsOneWidget);

        await tester.pump(_pastHold);
        expect(_titleMask, findsNothing);
      });

      testWidgets('stays for 4 seconds after every resume, then goes', (
        tester,
      ) async {
        await _go(tester, locale, _idle);
        await _go(tester, locale, _playing);
        await tester.pump(_justUnderHold + _pastHold);
        expect(_titleMask, findsNothing);

        await _go(tester, locale, _paused);
        expect(_titleMask, findsOneWidget);

        await _go(tester, locale, _playing);
        expect(_titleMask, findsOneWidget);
        await tester.pump(_justUnderHold);
        expect(_titleMask, findsOneWidget);
        await tester.pump(_pastHold);
        expect(_titleMask, findsNothing);
      });

      testWidgets('a seek with the app controls brings it back for 4 seconds', (
        tester,
      ) async {
        final seeks = <Duration>[];
        await _go(tester, locale, _idle, controlsVisible: true);
        await _go(
          tester,
          locale,
          _playing,
          controlsVisible: true,
          onSeek: seeks.add,
        );
        await tester.pump(_justUnderHold + _pastHold);
        expect(_titleMask, findsNothing);

        // The snapshot stays "playing" through the seek: only the app's own
        // seek tells the surface.
        await tester.tap(find.byTooltip(l10nFor(locale).forward10));
        await tester.pump();
        expect(seeks, [const Duration(seconds: 40)]);
        expect(_titleMask, findsOneWidget);

        await tester.pump(_justUnderHold);
        expect(_titleMask, findsOneWidget);
        await tester.pump(_pastHold);
        expect(_titleMask, findsNothing);
      });

      testWidgets('a surface mounted while playing holds it 4 seconds too', (
        tester,
      ) async {
        await _go(tester, locale, _playing);
        expect(_titleMask, findsOneWidget);
        await tester.pump(_justUnderHold);
        expect(_titleMask, findsOneWidget);
        await tester.pump(_pastHold);
        expect(_titleMask, findsNothing);
      });

      testWidgets('a new start restarts the 4 seconds (next lesson)', (
        tester,
      ) async {
        await _go(tester, locale, _playing);
        await tester.pump(const Duration(seconds: 3));
        // The next lesson loads: buffering, then playing again.
        await _go(
          tester,
          locale,
          const PlayerSnapshot(phase: PlayerPhase.buffering),
        );
        await _go(tester, locale, _playing);
        await tester.pump(const Duration(seconds: 3));
        expect(_titleMask, findsOneWidget, reason: '3s after the new start');
        await tester.pump(const Duration(milliseconds: 1100));
        expect(_titleMask, findsNothing);
      });

      testWidgets('leaving the screen cancels the hold (no late setState)', (
        tester,
      ) async {
        await _go(tester, locale, _idle);
        await _go(tester, locale, _playing);
        await tester.pumpWidget(localizedApp(locale, const SizedBox()));
        await tester.pump(const Duration(seconds: 10));
        expect(tester.takeException(), isNull);
      });

      testWidgets('its height scales with the player height', (tester) async {
        await _go(tester, locale, _paused, size: _portrait);
        final portrait = tester.getSize(_titleMask);

        await _go(tester, locale, _paused, size: _fullscreen);
        final full = tester.getSize(_titleMask);

        expect(portrait.width, _portrait.width);
        expect(full.width, _fullscreen.width);
        expect(
          portrait.height,
          closeTo(
            _portrait.height * ProtectedVideoSurface.titleMaskFraction,
            0.01,
          ),
        );
        expect(full.height, greaterThan(portrait.height));
        expect(
          full.height,
          closeTo(
            _fullscreen.height * ProtectedVideoSurface.titleMaskFraction,
            0.01,
          ),
        );
      });

      testWidgets('covers the top edge only, never the middle of the video', (
        tester,
      ) async {
        for (final size in [_portrait, _fullscreen, const Size(320, 180)]) {
          await _go(tester, locale, _paused, size: size);
          final rect = tester.getRect(_titleMask);
          expect(rect.top, 0, reason: '$size');
          expect(
            rect.bottom,
            lessThan(size.height / 2),
            reason: 'the centre of a $size video must stay unmasked',
          );
        }
      });
    });

    group('ProtectedVideoSurface logo corner [$name]', () {
      testWidgets('has no mask over the bottom-right corner in any state', (
        tester,
      ) async {
        for (final snapshot in [_idle, _paused, _playing]) {
          for (final size in [_portrait, _fullscreen]) {
            await _go(tester, locale, snapshot, size: size);
            // The old 76x28 patch was a Positioned(right: 0, bottom: 0).
            expect(
              find.byWidgetPredicate(
                (w) =>
                    w is Positioned &&
                    w.right == 0 &&
                    w.bottom == 0 &&
                    (w.width != null || w.height != null),
              ),
              findsNothing,
            );
            // And no mask-like box overlaps the corner: with the controls
            // hidden, the only Positioned ColoredBox is the title mask.
            final corner = Rect.fromLTWH(
              size.width - 76,
              size.height - 28,
              76,
              28,
            );
            final masks = find.byWidgetPredicate(
              (w) => w is Positioned && w.child is ColoredBox,
            );
            for (final mask in masks.evaluate()) {
              final rect = tester.getRect(find.byWidget(mask.widget));
              expect(
                rect.overlaps(corner),
                isFalse,
                reason: '$snapshot at $size: $rect covers the logo corner',
              );
            }
          }
        }
      });
    });
  }
}
