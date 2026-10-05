import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/secure_store.dart';
import 'package:wael_app/providers/locale_provider.dart';

void main() {
  group('resolveLocale (owner rule 2026-10-02)', () {
    test('Arabic device starts Arabic', () {
      expect(
        LocaleProvider.resolveLocale(saved: null, device: 'ar'),
        const Locale('ar'),
      );
      expect(
        LocaleProvider.resolveLocale(saved: null, device: 'ar_EG'),
        const Locale('ar'),
      );
    });

    test('English device starts English', () {
      expect(
        LocaleProvider.resolveLocale(saved: null, device: 'en'),
        const Locale('en'),
      );
      expect(
        LocaleProvider.resolveLocale(saved: null, device: 'en_US'),
        const Locale('en'),
      );
    });

    test('any other device language starts Arabic', () {
      for (final device in ['fr', 'fr_FR', 'de', 'es', 'ur', '']) {
        expect(
          LocaleProvider.resolveLocale(saved: null, device: device),
          const Locale('ar'),
          reason: 'device $device',
        );
      }
    });

    test('a saved choice beats the device', () {
      expect(
        LocaleProvider.resolveLocale(saved: 'en', device: 'ar'),
        const Locale('en'),
      );
      expect(
        LocaleProvider.resolveLocale(saved: 'ar', device: 'en'),
        const Locale('ar'),
      );
    });

    test('an unknown saved value falls back to the device rule', () {
      expect(
        LocaleProvider.resolveLocale(saved: 'fr', device: 'en'),
        const Locale('en'),
      );
      expect(
        LocaleProvider.resolveLocale(saved: '', device: 'fr'),
        const Locale('ar'),
      );
    });
  });

  group('LocaleProvider persistence', () {
    test('constructor starts on the device with no saved choice', () {
      final provider = LocaleProvider(deviceLanguageCode: 'ar');
      expect(provider.locale, const Locale('ar'));
      expect(provider.isArabic, isTrue);
    });

    test('load applies the saved choice before the first frame', () async {
      final store = MemoryTokenStore();
      await store.writeLocale('ar');
      final provider = LocaleProvider(store: store, deviceLanguageCode: 'en');
      expect(provider.locale, const Locale('en'));
      await provider.load();
      expect(provider.locale, const Locale('ar'));
      expect(provider.isArabic, isTrue);
    });

    test('load without a saved choice keeps the device locale', () async {
      final provider = LocaleProvider(
        store: MemoryTokenStore(),
        deviceLanguageCode: 'fr',
      );
      await provider.load();
      expect(provider.locale, const Locale('ar'));
    });

    test('toggling saves the new language', () async {
      final store = MemoryTokenStore();
      final provider = LocaleProvider(store: store, deviceLanguageCode: 'en');
      await provider.load();
      expect(provider.locale, const Locale('en'));

      provider.toggleLocale();
      expect(provider.locale, const Locale('ar'));
      expect(await store.readLocale(), 'ar');

      provider.toggleLocale();
      expect(provider.locale, const Locale('en'));
      expect(await store.readLocale(), 'en');
    });

    test('setLocale saves the choice and ignores repeats', () async {
      final store = MemoryTokenStore();
      final provider = LocaleProvider(store: store, deviceLanguageCode: 'en');
      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.setLocale(const Locale('ar'));
      expect(provider.locale, const Locale('ar'));
      expect(await store.readLocale(), 'ar');

      provider.setLocale(const Locale('ar'));
      expect(notifications, 1);
    });
  });
}
