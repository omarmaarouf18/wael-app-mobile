import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('AppTypography.uppercaseLabel', () {
    test('uppercases Latin text', () {
      expect(AppTypography.uppercaseLabel('Sign in'), 'SIGN IN');
    });

    test('leaves Arabic text unchanged', () {
      expect(AppTypography.uppercaseLabel('تسجيل الدخول'), 'تسجيل الدخول');
    });
  });

  group('semantic colours meet WCAG AA (4.5:1)', () {
    const surfaces = <String, Color>{
      'voidCanvas': AppColors.voidCanvas,
      'surfaceLayer1': AppColors.surfaceLayer1,
      'surfaceElevated': AppColors.surfaceElevated,
      'surfaceHigh': AppColors.surfaceHigh,
    };
    const pairs = <String, (Color, Color)>{
      'success': (AppColors.success, AppColors.successBg),
      'warning': (AppColors.warning, AppColors.warningBg),
      'danger': (AppColors.danger, AppColors.dangerBg),
      'info': (AppColors.info, AppColors.infoBg),
    };

    pairs.forEach((name, pair) {
      final (fg, bg) = pair;
      surfaces.forEach((surfaceName, surface) {
        test('$name on $surfaceName', () {
          expect(_contrast(fg, surface), greaterThanOrEqualTo(4.5));
        });
        test('$name on ${name}Bg over $surfaceName', () {
          final composited = Color.alphaBlend(bg, surface);
          expect(_contrast(fg, composited), greaterThanOrEqualTo(4.5));
        });
      });
    });
  });

  group('text tokens meet WCAG AA on the surfaces they are used on', () {
    // Small text needs 4.5:1; large text (>= 18.66px bold / 24px regular)
    // needs 3.0:1. Every pair below is small text the app renders, except
    // where marked large.
    const darkSurfaces = <String, Color>{
      'voidCanvas': AppColors.voidCanvas,
      'surfaceLayer1': AppColors.surfaceLayer1,
      'surfaceElevated': AppColors.surfaceElevated,
      'surfaceHigh': AppColors.surfaceHigh,
      'surfaceContainerLow': AppColors.surfaceContainerLow,
      'surfaceContainer': AppColors.surfaceContainer,
    };
    const smallText = <String, Color>{
      'textPrimary': AppColors.textPrimary,
      'textSecondary': AppColors.textSecondary,
      'textMuted': AppColors.textMuted,
      // F-UX4 (owner decision 2026-10-05): lightened, same hue, to reach AA.
      'textTertiary': AppColors.textTertiary,
      'success': AppColors.success,
      'warning': AppColors.warning,
      'danger': AppColors.danger,
      'info': AppColors.info,
    };

    smallText.forEach((tokenName, token) {
      darkSurfaces.forEach((surfaceName, surface) {
        test('$tokenName on $surfaceName', () {
          expect(
            _contrast(token, surface),
            greaterThanOrEqualTo(4.5),
            reason: '$tokenName on $surfaceName must reach WCAG AA 4.5:1',
          );
        });
      });
    });

    // textPlaceholder renders only in the settings footer on voidCanvas.
    // surfaceBright and surfaceContainerHighest carry no tertiary,
    // placeholder or danger text anywhere in lib/, so they are not asserted.
    test('textPlaceholder on voidCanvas', () {
      expect(
        _contrast(AppColors.textPlaceholder, AppColors.voidCanvas),
        greaterThanOrEqualTo(4.5),
      );
    });

    // The offline banner message (textPrimary) sits on warningBg.
    test('textPrimary on warningBg over voidCanvas', () {
      final composited = Color.alphaBlend(
        AppColors.warningBg,
        AppColors.voidCanvas,
      );
      expect(
        _contrast(AppColors.textPrimary, composited),
        greaterThanOrEqualTo(4.5),
      );
    });

    // Large-text rule (3.0:1): hero and display text are textPrimary, which
    // already clears 4.5 everywhere above; this pins the large threshold.
    test('large text needs 3.0:1 (displayHero on voidCanvas)', () {
      expect(
        _contrast(AppColors.textPrimary, AppColors.voidCanvas),
        greaterThanOrEqualTo(3.0),
      );
    });
  });
}
