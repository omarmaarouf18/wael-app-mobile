import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/secure_store.dart';
import 'package:wael_app/screens/splash_screen.dart';
import 'package:wael_app/widgets/app_shell.dart';

import 'screen_harness.dart';
import 'widget_layer_harness.dart';

void main() {
  for (final (name, locale, direction) in kLocales) {
    group('SplashScreen [$name]', () {
      testWidgets('shows the wordmark on the shared shell', (tester) async {
        await pumpScreen(tester, locale, const SplashScreen(), settle: false);
        expect(find.byType(AppShell), findsOneWidget);
        expect(find.byType(AppBar), findsNothing);
        expect(find.text('EL METR'), findsOneWidget);
        expect(find.text('ACADEMY'), findsOneWidget);
      });

      testWidgets('is centred and resolves $direction', (tester) async {
        await pumpScreen(tester, locale, const SplashScreen(), settle: false);
        expect(
          Directionality.of(tester.element(find.text('EL METR'))),
          direction,
        );
        final screen = tester.getSize(find.byType(Scaffold));
        expect(
          tester.getCenter(find.text('EL METR')).dx,
          closeTo(screen.width / 2, 1),
        );
      });

      testWidgets('without a session it replaces itself with /login', (
        tester,
      ) async {
        await pumpScreen(tester, locale, const SplashScreen());
        expect(find.text('route:/login'), findsOneWidget);
        expect(find.text('EL METR'), findsNothing);
      });

      testWidgets('with a valid session it goes to /main', (tester) async {
        final tokens = MemoryTokenStore();
        await tokens.writeTokens(access: 'access-1', refresh: 'refresh-1');
        await pumpScreen(
          tester,
          locale,
          const SplashScreen(),
          auth: makeAuth(tokens: tokens),
        );
        expect(find.text('route:/main'), findsOneWidget);
      });
    });
  }
}
