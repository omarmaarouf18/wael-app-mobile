import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'package:wael_app/core/legal_links.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/screens/settings/delete_account_screen.dart';
import 'package:wael_app/screens/settings_screen.dart';
import 'package:wael_app/screens/signup_screen.dart';

import 'academy_fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

void main() {
  group('legalLinks', () {
    test('terms falls back on empty, non-https and malformed config', () {
      expect(legalTermsUrl(''), legalTermsFallbackUrl);
      expect(legalTermsUrl('   '), legalTermsFallbackUrl);
      expect(
        legalTermsUrl('http://legal.elmetracademy.app/terms'),
        legalTermsFallbackUrl,
      );
      expect(legalTermsUrl('not a url'), legalTermsFallbackUrl);
      expect(legalTermsUrl('terms'), legalTermsFallbackUrl);
    });

    test('terms keeps a valid https config value', () {
      expect(
        legalTermsUrl('https://example.com/custom-terms'),
        'https://example.com/custom-terms',
      );
      expect(
        legalTermsUrl('https://legal.elmetracademy.app/terms'),
        'https://legal.elmetracademy.app/terms',
      );
    });

    test('privacy falls back on empty, non-https and malformed config', () {
      expect(legalPrivacyUrl(''), legalPrivacyFallbackUrl);
      expect(
        legalPrivacyUrl('http://legal.elmetracademy.app/privacy'),
        legalPrivacyFallbackUrl,
      );
      expect(legalPrivacyUrl('://missing-scheme'), legalPrivacyFallbackUrl);
    });

    test('privacy keeps a valid https config value', () {
      expect(
        legalPrivacyUrl('https://example.com/custom-privacy'),
        'https://example.com/custom-privacy',
      );
    });

    test('delete-account page is always the fallback', () {
      expect(legalDeleteAccountUrl(), legalDeleteAccountFallbackUrl);
      expect(
        legalDeleteAccountFallbackUrl,
        'https://legal.elmetracademy.app/delete-account',
      );
    });

    test('English UI appends #en, Arabic does not', () {
      expect(
        withUiLanguage('https://legal.elmetracademy.app/terms', isArabic: true),
        'https://legal.elmetracademy.app/terms',
      );
      expect(
        withUiLanguage(
          'https://legal.elmetracademy.app/terms',
          isArabic: false,
        ),
        'https://legal.elmetracademy.app/terms#en',
      );
      // A URL that already carries a fragment is left alone.
      expect(
        withUiLanguage('https://example.com/t#section', isArabic: false),
        'https://example.com/t#section',
      );
    });

    test('openLegalPage opens https only', () async {
      final launched = <Uri>[];
      Future<bool> launch(
        Uri uri, {
        LaunchMode mode = LaunchMode.externalApplication,
      }) async {
        launched.add(uri);
        return true;
      }

      expect(
        await openLegalPage(
          'https://legal.elmetracademy.app/terms',
          launch: launch,
        ),
        isTrue,
      );
      expect(
        await openLegalPage(
          'http://legal.elmetracademy.app/terms',
          launch: launch,
        ),
        isFalse,
      );
      expect(await openLegalPage('not a url', launch: launch), isFalse);
      expect(launched.map((u) => u.toString()), [
        'https://legal.elmetracademy.app/terms',
      ]);
    });
  });

  for (final (name, locale, _) in kLocales) {
    final l10n = l10nFor(locale);
    final isArabic = locale.languageCode == 'ar';
    String en(String url) => isArabic ? url : '$url#en';

    group('legal links always work [$name]', () {
      testWidgets('signup shows the terms link with empty app-config', (
        tester,
      ) async {
        final launched = <Uri>[];
        await pumpScreen(
          tester,
          locale,
          SignupScreen(
            launchUrl: (uri, {mode = LaunchMode.externalApplication}) async {
              launched.add(uri);
              return true;
            },
          ),
          size: const Size(390, 1400),
        );
        expect(find.text(l10n.readTerms), findsOneWidget);
        await tester.tap(find.text(l10n.readTerms));
        await tester.pump();
        expect(launched.map((u) => u.toString()), [
          en('https://legal.elmetracademy.app/terms'),
        ]);
      });

      testWidgets('settings shows terms and privacy with empty app-config', (
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
          size: const Size(390, 1800),
        );
        expect(find.text(l10n.termsTitle), findsOneWidget);
        expect(find.text(l10n.privacyTitle), findsOneWidget);
        await tester.tap(find.text(l10n.termsTitle));
        await tester.pump();
        await tester.tap(find.text(l10n.privacyTitle));
        await tester.pump();
        expect(launched.map((u) => u.toString()), [
          en('https://legal.elmetracademy.app/terms'),
          en('https://legal.elmetracademy.app/privacy'),
        ]);
      });

      testWidgets('delete screen links to the how-to-delete page', (
        tester,
      ) async {
        final launched = <Uri>[];
        await pumpScreen(
          tester,
          locale,
          DeleteAccountScreen(
            launchUrl: (uri, {mode = LaunchMode.externalApplication}) async {
              launched.add(uri);
              return true;
            },
          ),
          extraProviders: [
            ChangeNotifierProvider<AcademyCatalogProvider>.value(
              value: AcademyCatalogProvider(fake()),
            ),
          ],
          size: const Size(390, 1400),
        );
        expect(find.text(l10n.deleteAccountWebHelp), findsOneWidget);
        await tester.tap(find.text(l10n.deleteAccountWebHelp));
        await tester.pump();
        expect(launched.map((u) => u.toString()), [
          en('https://legal.elmetracademy.app/delete-account'),
        ]);
      });
    });
  }
}
