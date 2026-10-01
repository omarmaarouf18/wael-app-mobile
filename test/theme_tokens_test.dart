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
}
