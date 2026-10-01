import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/theme.dart';
import 'package:wael_app/l10n/app_localizations.dart';

/// The two app locales and the text direction each must resolve to.
const kLocales = <(String, Locale, TextDirection)>[
  ('en', Locale('en'), TextDirection.ltr),
  ('ar', Locale('ar'), TextDirection.rtl),
];

Widget localizedApp(
  Locale locale,
  Widget home, {
  Map<String, WidgetBuilder> routes = const {},
}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    locale: locale,
    supportedLocales: const [Locale('en', ''), Locale('ar', '')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
    routes: routes,
  );
}

/// Pumps [home] under [locale]. Pass `settle: false` for trees with an
/// indeterminate spinner, which never lets `pumpAndSettle` finish.
Future<void> pumpLocalized(
  WidgetTester tester,
  Locale locale,
  Widget home, {
  bool settle = true,
}) async {
  await tester.pumpWidget(localizedApp(locale, home));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Strings for [locale], read from the same class the widgets use.
AppLocalizations l10nFor(Locale locale) => AppLocalizations(locale);
