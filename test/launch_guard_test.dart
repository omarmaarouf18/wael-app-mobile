import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'package:wael_app/core/app_config_cache.dart';
import 'package:wael_app/core/external_links.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/screens/settings_screen.dart';
import 'package:wael_app/screens/update_gate_screen.dart';

import 'screen_harness.dart';
import 'widget_layer_harness.dart';

// UX table 2026-10-12: a double tap on an external link (WhatsApp, update,
// legal pages) opened it twice. One shared guard (LaunchGuard) now ignores a
// second tap on the same link while it launches and for 1 s after.

class _Clock {
  DateTime now = DateTime.utc(2026, 10, 12, 12);
}

void main() {
  late _Clock clock;
  setUp(() {
    clock = _Clock();
    LaunchGuard.instance.clock = () => clock.now;
  });

  group('LaunchGuard', () {
    test(
      'a double tap launches once; after the cooldown it works again',
      () async {
        var launches = 0;
        Future<bool> launch() async {
          launches++;
          return true;
        }

        final guard = LaunchGuard.instance;
        await guard.run('a', launch);
        await guard.run('a', launch);
        expect(launches, 1);

        clock.now = clock.now.add(const Duration(milliseconds: 1100));
        await guard.run('a', launch);
        expect(launches, 2);
      },
    );

    test('a tap while the launch is in flight is ignored', () async {
      var launches = 0;
      final gate = Completer<bool>();
      final guard = LaunchGuard.instance;
      final first = guard.run('a', () {
        launches++;
        return gate.future;
      });
      // Even long after, while the first launch has not returned.
      clock.now = clock.now.add(const Duration(seconds: 10));
      await guard.run('a', () async {
        launches++;
        return true;
      });
      gate.complete(true);
      expect(await first, isTrue);
      expect(launches, 1);
    });

    test('different links are independent', () async {
      final opened = <String>[];
      final guard = LaunchGuard.instance;
      await guard.run('terms', () async {
        opened.add('terms');
        return true;
      });
      await guard.run('privacy', () async {
        opened.add('privacy');
        return true;
      });
      expect(opened, ['terms', 'privacy']);
    });

    test(
      'openSupportChat: app attempt and browser fallback count as one',
      () async {
        final modes = <LaunchMode>[];
        Future<bool> launch(
          Uri uri, {
          LaunchMode mode = LaunchMode.platformDefault,
        }) async {
          modes.add(mode);
          return mode == LaunchMode.platformDefault; // app missing, browser ok
        }

        expect(
          await openSupportChat(
            supportUrl: 'https://wa.me/201000000000',
            messageText: 'hi',
            launch: launch,
          ),
          isTrue,
        );
        await openSupportChat(
          supportUrl: 'https://wa.me/201000000000',
          messageText: 'hi',
          launch: launch,
        );
        expect(modes, [
          LaunchMode.externalApplication,
          LaunchMode.platformDefault,
        ]);
      },
    );
  });

  final (_, locale, _) = kLocales.first;
  final l10n = l10nFor(locale);

  testWidgets('update gate: a double tap on "Update now" opens one link', (
    tester,
  ) async {
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
      appConfig:
          AppConfigProvider(
            cache: MemoryAppConfigCache(),
            versionReader: () async => '1.0.0',
          )..setForTesting(
            const AppConfigData(
              minVersion: '2.0.0',
              updateUrl: 'https://elmetracademy.app/app.apk',
            ),
          ),
    );
    await tester.tap(find.text(l10n.updateNow));
    await tester.tap(find.text(l10n.updateNow));
    await tester.pump();
    expect(launched, hasLength(1));

    clock.now = clock.now.add(const Duration(milliseconds: 1100));
    await tester.tap(find.text(l10n.updateNow));
    await tester.pump();
    expect(launched, hasLength(2));
  });

  testWidgets('settings: double taps on WhatsApp and Terms open each once', (
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
      appConfig:
          AppConfigProvider(
            cache: MemoryAppConfigCache(),
            versionReader: () async => '1.0.0',
          )..setForTesting(
            const AppConfigData(
              supportWhatsappUrl: 'https://wa.me/201000000000',
              termsUrl: 'https://legal.elmetracademy.app/terms',
            ),
          ),
      size: const Size(390, 1800),
    );
    await tester.tap(find.text(l10n.contactWhatsApp));
    await tester.tap(find.text(l10n.contactWhatsApp));
    await tester.pump();
    expect(launched.where((u) => u.host == 'wa.me'), hasLength(1));

    await tester.tap(find.text(l10n.termsTitle));
    await tester.tap(find.text(l10n.termsTitle));
    await tester.pump();
    expect(
      launched.where((u) => u.host == 'legal.elmetracademy.app'),
      hasLength(1),
    );
  });
}
