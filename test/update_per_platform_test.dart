import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'package:wael_app/core/app_config_cache.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/screens/settings_screen.dart';
import 'package:wael_app/screens/update_gate_screen.dart';

import 'screen_harness.dart';
import 'widget_layer_harness.dart';

// Owner decision 2026-10-12: the update link and versions are per platform.
// Android × iOS × (per-platform | shared | none) × (required | available |
// none), and iOS never opens a link that is not on apps.apple.com.

const _play = 'https://play.google.com/store/apps/details?id=app.x';
const _apk = 'https://elmetracademy.app/download/app.apk';
const _appStore = 'https://apps.apple.com/app/el-metr-academy/id1234567890';
const _support = 'https://wa.me/201000000000';

enum _Source { perPlatform, shared, none }

enum _Want { required, available, none }

/// Builds the app-config for one cell of the matrix. The installed version
/// is always 1.0.0.
AppConfigData _data(_Source source, _Want want, {String support = ''}) {
  final min = want == _Want.required ? '2.0.0' : '';
  final latest = want == _Want.none ? '1.0.0' : '2.0.0';
  switch (source) {
    case _Source.perPlatform:
      // The shared fields say "no update" so a pass proves the platform's
      // own fields were read (Android has no own versions: shared ones).
      return AppConfigData(
        updateUrl: _apk,
        updateUrlAndroid: _play,
        updateUrlIos: _appStore,
        minVersion: min,
        latestVersion: latest,
        minVersionIos: min,
        latestVersionIos: latest,
        supportWhatsappUrl: support,
      );
    case _Source.shared:
      return AppConfigData(
        updateUrl: _apk,
        minVersion: min,
        latestVersion: latest,
        supportWhatsappUrl: support,
      );
    case _Source.none:
      return AppConfigData(
        minVersion: min,
        latestVersion: latest,
        supportWhatsappUrl: support,
      );
  }
}

/// The link each platform must use for [source]: Android takes its own link,
/// then the shared one; iOS only an App Store link (the shared one here is an
/// APK, so iOS has none).
String _expectedUrl(TargetPlatform p, _Source source) {
  if (p == TargetPlatform.iOS) {
    return source == _Source.perPlatform ? _appStore : '';
  }
  return switch (source) {
    _Source.perPlatform => _play,
    _Source.shared => _apk,
    _Source.none => '',
  };
}

AppConfigProvider _provider(AppConfigData data, {String version = '1.0.0'}) =>
    AppConfigProvider(
      cache: MemoryAppConfigCache(),
      versionReader: () async => version,
    )..setForTesting(data);

UpdateState _state(_Want w) => switch (w) {
  _Want.required => UpdateState.required,
  _Want.available => UpdateState.available,
  _Want.none => UpdateState.none,
};

void main() {
  group('AppConfigData per-platform fields', () {
    test('parses the four new fields, drops non-https links', () {
      final c = AppConfigData.fromJson({
        'update_url_android': _play,
        'update_url_ios': _appStore,
        'min_version_ios': ' 1.0.1 ',
        'latest_version_ios': '1.0.2',
      });
      expect(c.updateUrlAndroid, _play);
      expect(c.updateUrlIos, _appStore);
      expect(c.minVersionIos, '1.0.1');
      expect(c.latestVersionIos, '1.0.2');

      final bad = AppConfigData.fromJson({
        'update_url_android': 'http://example.com/app.apk',
        'update_url_ios': 'itms-apps://apps.apple.com/app/id1',
      });
      expect(bad.updateUrlAndroid, '');
      expect(bad.updateUrlIos, '');
    });

    test('old 1.0.0-shaped config (no new fields) parses as before', () {
      final c = AppConfigData.fromJson({
        'update_url': _apk,
        'min_version': '1.0.0',
        'latest_version': '1.0.1',
      });
      expect(c.updateUrl, _apk);
      expect(c.updateUrlAndroid, '');
      expect(c.updateUrlIos, '');
      expect(c.minVersionIos, '');
      expect(c.latestVersionIos, '');
    });

    test('toJson round-trips the per-platform fields', () {
      final c = _data(_Source.perPlatform, _Want.required);
      final back = AppConfigData.fromJson(c.toJson());
      expect(back.updateUrlAndroid, _play);
      expect(back.updateUrlIos, _appStore);
      expect(back.minVersionIos, '2.0.0');
      expect(back.latestVersionIos, '2.0.0');
    });

    test('isAppStoreUrl accepts only https apps.apple.com', () {
      expect(isAppStoreUrl(_appStore), isTrue);
      expect(isAppStoreUrl('https://APPS.apple.com/app/id1'), isTrue);
      expect(isAppStoreUrl('http://apps.apple.com/app/id1'), isFalse);
      expect(isAppStoreUrl('https://apps.apple.com.evil.example/x'), isFalse);
      expect(isAppStoreUrl('https://evil.example/apps.apple.com'), isFalse);
      expect(isAppStoreUrl(_play), isFalse);
      expect(isAppStoreUrl(_apk), isFalse);
      expect(isAppStoreUrl(''), isFalse);
    });
  });

  group('AppConfigProvider per-platform matrix', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      for (final source in _Source.values) {
        for (final want in _Want.values) {
          test('${platform.name} × ${source.name} × ${want.name}', () {
            final p = _provider(_data(source, want));
            expect(p.updateState('1.0.0', platform), _state(want));
            expect(p.updateUrlFor(platform), _expectedUrl(platform, source));
          });
        }
      }
    }

    test('iOS reads min_version_ios before the shared min_version', () {
      final p = _provider(
        const AppConfigData(
          minVersion: '2.0.0',
          minVersionIos: '1.0.0',
          latestVersion: '2.0.0',
          latestVersionIos: '1.0.0',
        ),
      );
      expect(p.updateState('1.0.0', TargetPlatform.iOS), UpdateState.none);
      expect(
        p.updateState('1.0.0', TargetPlatform.android),
        UpdateState.required,
      );
    });

    test('iOS falls back to the shared versions when its own are absent', () {
      final p = _provider(const AppConfigData(minVersion: '2.0.0'));
      expect(p.updateState('1.0.0', TargetPlatform.iOS), UpdateState.required);
    });

    test('Android ignores the iOS-only versions', () {
      final p = _provider(const AppConfigData(minVersionIos: '2.0.0'));
      expect(p.updateState('1.0.0', TargetPlatform.android), UpdateState.none);
      expect(p.updateState('1.0.0', TargetPlatform.iOS), UpdateState.required);
    });

    test('iOS uses a shared update_url only when it is an App Store link', () {
      final p = _provider(const AppConfigData(updateUrl: _appStore));
      expect(p.updateUrlFor(TargetPlatform.iOS), _appStore);
      // ...and Android never offers an App Store link.
      expect(p.updateUrlFor(TargetPlatform.android), '');
    });

    test(
      'iOS never returns a non-App-Store link, whatever the server sends',
      () {
        for (final url in [_apk, _play, 'https://elmetracademy.app/']) {
          final p = _provider(
            AppConfigData(
              updateUrl: url,
              updateUrlIos: url,
              updateUrlAndroid: url,
            ),
          );
          expect(p.updateUrlFor(TargetPlatform.iOS), '', reason: url);
        }
      },
    );

    test('version 1.0.1 (this build) is not below min 1.0.1', () {
      final p = _provider(const AppConfigData(minVersion: '1.0.1'));
      expect(p.updateState('1.0.1', TargetPlatform.android), UpdateState.none);
      expect(
        p.updateState('1.0.0', TargetPlatform.android),
        UpdateState.required,
      );
    });
  });

  final platforms = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.iOS,
  });

  for (final (name, locale, _) in kLocales) {
    final l10n = l10nFor(locale);

    group('UpdateGateScreen per platform [$name]', () {
      for (final source in _Source.values) {
        for (final withSupport in [true, false]) {
          testWidgets('required × ${source.name} × support=$withSupport', (
            tester,
          ) async {
            final platform = defaultTargetPlatform;
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
              appConfig: _provider(
                _data(
                  source,
                  _Want.required,
                  support: withSupport ? _support : '',
                ),
              ),
            );

            final url = _expectedUrl(platform, source);
            if (url.isNotEmpty) {
              expect(find.text(l10n.updateNow), findsOneWidget);
              expect(find.text(l10n.contactWhatsApp), findsNothing);
              await tester.tap(find.text(l10n.updateNow));
              await tester.pump();
              expect(launched.map((u) => u.toString()), [url]);
            } else if (withSupport) {
              // No usable link: the WhatsApp button, never a dead end.
              expect(find.text(l10n.updateNow), findsNothing);
              expect(find.text(l10n.updateContactSupport), findsOneWidget);
              expect(find.text(l10n.contactWhatsApp), findsOneWidget);
              await tester.tap(find.text(l10n.contactWhatsApp));
              await tester.pump();
              expect(launched, hasLength(1));
              expect(launched.single.host, 'wa.me');
            } else {
              expect(find.text(l10n.updateNow), findsNothing);
              expect(find.text(l10n.contactWhatsApp), findsNothing);
              expect(find.text(l10n.updateContactSupport), findsOneWidget);
            }
            if (platform == TargetPlatform.iOS) {
              for (final u in launched) {
                expect(u.host, anyOf('apps.apple.com', 'wa.me'));
              }
            }
          }, variant: platforms);
        }
      }
    });

    group('Settings update tile per platform [$name]', () {
      for (final source in _Source.values) {
        for (final want in _Want.values) {
          testWidgets('${want.name} × ${source.name}', (tester) async {
            final platform = defaultTargetPlatform;
            final launched = <Uri>[];
            await pumpScreen(
              tester,
              locale,
              SettingsScreen(
                launchUrl:
                    (uri, {mode = LaunchMode.externalApplication}) async {
                      launched.add(uri);
                      return true;
                    },
              ),
              appConfig: _provider(_data(source, want, support: _support)),
              size: const Size(390, 1800),
            );

            // The tile is for "available" only; "required" is the gate.
            if (want != _Want.available) {
              expect(find.text(l10n.updateAvailable), findsNothing);
              return;
            }
            expect(find.text(l10n.updateAvailable), findsOneWidget);
            await tester.tap(find.text(l10n.updateAvailable));
            await tester.pump();
            final url = _expectedUrl(platform, source);
            expect(launched, hasLength(1));
            if (url.isNotEmpty) {
              expect(launched.single.toString(), url);
            } else {
              expect(launched.single.host, 'wa.me');
            }
            if (platform == TargetPlatform.iOS) {
              expect(launched.single.host, anyOf('apps.apple.com', 'wa.me'));
            }
          }, variant: platforms);
        }
      }

      testWidgets(
        'available with no usable link and no support hides the tile',
        (tester) async {
          await pumpScreen(
            tester,
            locale,
            const SettingsScreen(),
            appConfig: _provider(_data(_Source.none, _Want.available)),
            size: const Size(390, 1800),
          );
          expect(find.text(l10n.updateAvailable), findsNothing);
        },
        variant: platforms,
      );
    });
  }
}
