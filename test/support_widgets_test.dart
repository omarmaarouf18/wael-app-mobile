import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/theme.dart';
import 'package:wael_app/widgets/app_shell.dart';
import 'package:wael_app/widgets/hero_backdrop.dart';
import 'package:wael_app/widgets/language_toggle_chip.dart';

import 'widget_layer_harness.dart';

void main() {
  for (final (name, locale, direction) in kLocales) {
    group('[$name]', () {
      testWidgets('AppShell safeArea: true pads the body by the top inset', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = const FakeViewPadding(top: 40);
        tester.view.viewPadding = const FakeViewPadding(top: 40);
        addTearDown(tester.view.reset);
        await pumpLocalized(
          tester,
          locale,
          const AppShell(
            showHeader: false,
            body: SizedBox.expand(key: Key('body')),
          ),
        );
        expect(tester.getTopLeft(find.byKey(const Key('body'))).dy, 40);
      });

      testWidgets('AppShell safeArea: true also keeps the bottom inset', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = const FakeViewPadding(bottom: 34);
        tester.view.viewPadding = const FakeViewPadding(bottom: 34);
        addTearDown(tester.view.reset);
        await pumpLocalized(
          tester,
          locale,
          const AppShell(
            showHeader: false,
            body: SizedBox.expand(key: Key('body')),
          ),
        );
        final screen = tester.getSize(find.byType(Scaffold)).height;
        expect(
          tester.getBottomLeft(find.byKey(const Key('body'))).dy,
          screen - 34,
        );
      });

      testWidgets('AppShell safeArea: false lets the body bleed to the top', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = const FakeViewPadding(top: 40);
        tester.view.viewPadding = const FakeViewPadding(top: 40);
        addTearDown(tester.view.reset);
        await pumpLocalized(
          tester,
          locale,
          const AppShell(
            showHeader: false,
            safeArea: false,
            body: SizedBox.expand(key: Key('body')),
          ),
        );
        expect(tester.getTopLeft(find.byKey(const Key('body'))).dy, 0);
      });

      testWidgets('HeroBackdrop is a fraction of the screen height', (
        tester,
      ) async {
        await pumpLocalized(
          tester,
          locale,
          const Scaffold(
            body: Stack(
              children: [
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  end: 0,
                  child: HeroBackdrop(
                    imageAsset: 'assets/does-not-exist-1.png',
                    fallbackAsset: 'assets/does-not-exist-2.png',
                    heightFactor: 0.5,
                  ),
                ),
              ],
            ),
          ),
        );
        final screen = tester.getSize(find.byType(Scaffold));
        final backdrop = tester.getSize(find.byType(HeroBackdrop));
        expect(backdrop.height, closeTo(screen.height * 0.5, 0.5));
        expect(backdrop.width, screen.width);
        // Both images are missing: the flat fallback surface is shown.
        expect(
          find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == AppColors.surfaceLayer1,
          ),
          findsOneWidget,
        );
      });

      testWidgets('LanguageToggleChip: icon at the start, label after, taps', (
        tester,
      ) async {
        var taps = 0;
        await pumpLocalized(
          tester,
          locale,
          Scaffold(
            body: Center(
              child: LanguageToggleChip(label: 'English', onTap: () => taps++),
            ),
          ),
        );
        final icon = tester.getCenter(find.byIcon(Icons.language)).dx;
        final label = tester.getCenter(find.text('English')).dx;
        if (direction == TextDirection.ltr) {
          expect(icon, lessThan(label));
        } else {
          expect(icon, greaterThan(label));
        }
        await tester.tap(find.byType(LanguageToggleChip));
        expect(taps, 1);
      });
    });
  }

  test('wordmark styles carry the hero spacing and shadows', () {
    final title = AppTypography.wordmarkTitle();
    expect(title.fontSize, 32);
    expect(title.letterSpacing, 6.0);
    expect(title.shadows, isNotEmpty);
    final subtitle = AppTypography.wordmarkSubtitle();
    expect(subtitle.fontSize, 11);
    expect(subtitle.letterSpacing, 4.5);
  });
}
