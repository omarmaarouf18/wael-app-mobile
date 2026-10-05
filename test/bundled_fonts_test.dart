import 'dart:io' show HttpClient, HttpOverrides, SecurityContext;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wael_app/core/theme.dart';

import 'widget_layer_harness.dart';

/// Fonts are bundled as assets (pubspec `fonts:`) and runtime fetching is
/// disabled: the app renders offline with no request to Google.
class _DenyNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError('network denied in bundled-fonts test');
  }
}

void main() {
  testWidgets('bundled fonts render with runtime fetching disabled', (
    tester,
  ) async {
    final previous = GoogleFonts.config.allowRuntimeFetching;
    GoogleFonts.config.allowRuntimeFetching = false;
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = _DenyNetwork();
    try {
      // Exercise every bundled family/weight the theme uses.
      await pumpLocalized(
        tester,
        const Locale('ar'),
        Scaffold(
          body: Column(
            children: [
              Text('عناوين', style: AppTypography.displayHero(isArabic: true)),
              Text(
                'Headline',
                style: AppTypography.headlineLg(isArabic: false),
              ),
              Text('نص', style: AppTypography.bodyMd(isArabic: true)),
              Text('Body', style: AppTypography.bodySm(isArabic: false)),
              Text('Label', style: AppTypography.labelSm(isArabic: false)),
            ],
          ),
        ),
      );
      expect(find.text('عناوين'), findsOneWidget);
      expect(find.text('Headline'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    } finally {
      GoogleFonts.config.allowRuntimeFetching = previous;
      HttpOverrides.global = previousOverrides;
    }
  });
}
