import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'package:wael_app/core/app_config_cache.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/screens/settings_screen.dart';

import 'screen_harness.dart';
import 'widget_layer_harness.dart';

const _tall = Size(390, 1800);

AppConfigProvider configWith({
  AppConfigData data = const AppConfigData(
    supportWhatsappUrl: 'https://wa.me/201000000000',
    termsUrl: 'https://legal.elmetracademy.app/terms',
    privacyUrl: 'https://legal.elmetracademy.app/privacy',
  ),
  String version = '1.0.0',
}) => AppConfigProvider(
  cache: MemoryAppConfigCache(),
  versionReader: () async => version,
)..setForTesting(data);

void main() {
  for (final (name, locale, _) in kLocales) {
    final l10n = l10nFor(locale);
    final isArabic = locale.languageCode == 'ar';
    String en(String url) => isArabic ? url : '$url#en';

    group('SettingsScreen about [$name]', () {
      testWidgets('terms and privacy open the server URLs', (tester) async {
        final launched = <Uri>[];
        await pumpScreen(
          tester,
          locale,
          SettingsScreen(
            launchUrl: (uri, {mode = LaunchMode.externalApplication}) async {
              launched.add(uri);
              return true;
            },
          ),
          appConfig: configWith(),
          size: _tall,
        );
        await tester.tap(find.text(l10n.termsTitle));
        await tester.pump();
        await tester.tap(find.text(l10n.privacyTitle));
        await tester.pump();
        expect(launched.map((u) => u.toString()), [
          en('https://legal.elmetracademy.app/terms'),
          en('https://legal.elmetracademy.app/privacy'),
        ]);
      });

      testWidgets('tiles fall back when the server configures nothing', (
        tester,
      ) async {
        final launched = <Uri>[];
        await pumpScreen(
          tester,
          locale,
          SettingsScreen(
            launchUrl: (uri, {mode = LaunchMode.externalApplication}) async {
              launched.add(uri);
              return true;
            },
          ),
          appConfig: configWith(data: const AppConfigData()),
          size: _tall,
        );
        expect(find.text(l10n.termsTitle), findsOneWidget);
        expect(find.text(l10n.privacyTitle), findsOneWidget);
        expect(find.text(l10n.appVersion), findsOneWidget);
        await tester.tap(find.text(l10n.termsTitle));
        await tester.pump();
        await tester.tap(find.text(l10n.privacyTitle));
        await tester.pump();
        expect(launched.map((u) => u.toString()), [
          en('https://legal.elmetracademy.app/terms'),
          en('https://legal.elmetracademy.app/privacy'),
        ]);
      });

      testWidgets('shows the installed version', (tester) async {
        await pumpScreen(
          tester,
          locale,
          const SettingsScreen(),
          appConfig: configWith(version: '1.2.3'),
          size: _tall,
        );
        expect(find.text('1.2.3'), findsOneWidget);
      });

      testWidgets(
        'shows update available row when latest > current and opens URL externally',
        (tester) async {
          final launched = <Uri>[];
          await pumpScreen(
            tester,
            locale,
            SettingsScreen(
              launchUrl: (uri, {mode = LaunchMode.externalApplication}) async {
                launched.add(uri);
                return true;
              },
            ),
            appConfig: configWith(
              data: const AppConfigData(
                latestVersion: '2.0.0',
                updateUrl: 'https://elmetracademy.app/download',
              ),
              version: '1.0.0',
            ),
            size: _tall,
          );
          expect(find.text(l10n.updateAvailable), findsOneWidget);
          await tester.tap(find.text(l10n.updateAvailable));
          await tester.pump();
          expect(launched.map((u) => u.toString()), [
            'https://elmetracademy.app/download',
          ]);
        },
      );

      testWidgets('hides update available row when current >= latest', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          locale,
          const SettingsScreen(),
          appConfig: configWith(
            data: const AppConfigData(
              latestVersion: '1.0.0',
              updateUrl: 'https://elmetracademy.app/download',
            ),
            version: '1.0.0',
          ),
          size: _tall,
        );
        expect(find.text(l10n.updateAvailable), findsNothing);
      });

      testWidgets('hides update available row when updateUrl is empty', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          locale,
          const SettingsScreen(),
          appConfig: configWith(
            data: const AppConfigData(latestVersion: '2.0.0', updateUrl: ''),
            version: '1.0.0',
          ),
          size: _tall,
        );
        expect(find.text(l10n.updateAvailable), findsNothing);
      });
    });
  }
}
