import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'package:wael_app/core/app_config_cache.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/screens/update_gate_screen.dart';

import 'screen_harness.dart';
import 'widget_layer_harness.dart';

AppConfigProvider _configWith({
  String minVersion = '2.0.0',
  String updateUrl = 'https://elmetracademy.app/download',
  String currentVersion = '1.0.0',
}) => AppConfigProvider(
  cache: MemoryAppConfigCache(),
  versionReader: () async => currentVersion,
)..setForTesting(AppConfigData(minVersion: minVersion, updateUrl: updateUrl));

void main() {
  for (final (name, locale, _) in kLocales) {
    final l10n = l10nFor(locale);

    group('UpdateGateScreen [$name]', () {
      testWidgets(
        'renders title, message and update button when updateUrl present',
        (tester) async {
          final launched = <Uri>[];
          await pumpScreen(
            tester,
            locale,
            UpdateGateScreen(
              launch: (uri, {mode = LaunchMode.externalApplication}) async {
                launched.add(uri);
                return true;
              },
            ),
            appConfig: _configWith(),
          );

          expect(find.text(l10n.updateRequiredTitle), findsOneWidget);
          expect(find.text(l10n.updateRequiredMessage), findsOneWidget);
          expect(find.text(l10n.updateNow), findsOneWidget);
          expect(find.text(l10n.updateContactSupport), findsNothing);

          await tester.tap(find.text(l10n.updateNow));
          await tester.pump();
          expect(launched.map((u) => u.toString()), [
            'https://elmetracademy.app/download',
          ]);
        },
      );

      testWidgets('renders contact support message when updateUrl is empty', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          locale,
          const UpdateGateScreen(),
          appConfig: _configWith(updateUrl: ''),
        );

        expect(find.text(l10n.updateRequiredTitle), findsOneWidget);
        expect(find.text(l10n.updateRequiredMessage), findsOneWidget);
        expect(find.text(l10n.updateNow), findsNothing);
        expect(find.text(l10n.updateContactSupport), findsOneWidget);
      });

      testWidgets('no overflow at textScaler 2.0', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await pumpScreen(
          tester,
          locale,
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: UpdateGateScreen(
                launch: (uri, {mode = LaunchMode.externalApplication}) async =>
                    true,
              ),
            ),
          ),
          appConfig: _configWith(),
        );
        expect(tester.takeException(), isNull);
      });
    });
  }
}
