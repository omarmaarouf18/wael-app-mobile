import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/app_config_cache.dart';
import 'package:wael_app/core/secure_store.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/repositories/academy_repository.dart';
import 'package:wael_app/screens/splash_screen.dart';
import 'package:wael_app/widgets/app_shell.dart';

import 'screen_harness.dart';
import 'widget_layer_harness.dart';
import 'fakes.dart';

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

      testWidgets('a hanging restore takes the offline branch to /main', (
        tester,
      ) async {
        final tokens = MemoryTokenStore();
        await tokens.writeTokens(access: 'access-1', refresh: 'refresh-1');
        await pumpScreen(
          tester,
          locale,
          const SplashScreen(restoreBudget: Duration(milliseconds: 100)),
          auth: makeAuth(
            repository: FakeAuthRepository()..meMode = 'hang',
            tokens: tokens,
          ),
        );
        expect(find.text('route:/main'), findsOneWidget);
      });

      testWidgets('routes to /update-gate when current < min_version', (
        tester,
      ) async {
        final config = AppConfigProvider(
          cache: MemoryAppConfigCache(),
          versionReader: () async => '1.0.0',
        )..setForTesting(const AppConfigData(minVersion: '2.0.0'));
        await pumpScreen(
          tester,
          locale,
          const SplashScreen(),
          appConfig: config,
        );
        expect(find.text('route:/update-gate'), findsOneWidget);
      });

      testWidgets('routes normally to /login when current >= min_version', (
        tester,
      ) async {
        final config = AppConfigProvider(
          cache: MemoryAppConfigCache(),
          versionReader: () async => '2.0.0',
        )..setForTesting(const AppConfigData(minVersion: '2.0.0'));
        await pumpScreen(
          tester,
          locale,
          const SplashScreen(),
          appConfig: config,
        );
        expect(find.text('route:/login'), findsOneWidget);
        expect(find.text('route:/update-gate'), findsNothing);
      });

      testWidgets('gate absent when min_version is empty', (tester) async {
        final config = AppConfigProvider(
          cache: MemoryAppConfigCache(),
          versionReader: () async => '1.0.0',
        )..setForTesting(const AppConfigData(minVersion: ''));
        await pumpScreen(
          tester,
          locale,
          const SplashScreen(),
          appConfig: config,
        );
        expect(find.text('route:/login'), findsOneWidget);
        expect(find.text('route:/update-gate'), findsNothing);
      });

      testWidgets('gate absent when config fetch fails (fails soft)', (
        tester,
      ) async {
        final config = AppConfigProvider(
          repository: _FailingRepo(),
          cache: MemoryAppConfigCache(),
          versionReader: () async => '1.0.0',
        );
        await pumpScreen(
          tester,
          locale,
          const SplashScreen(),
          appConfig: config,
        );
        expect(find.text('route:/login'), findsOneWidget);
        expect(find.text('route:/update-gate'), findsNothing);
      });
    });
  }
}

class _FailingRepo implements AcademyRepository {
  @override
  Future<AppConfigData> appConfig() async =>
      throw ApiException(statusCode: 500, message: 'Server down');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
