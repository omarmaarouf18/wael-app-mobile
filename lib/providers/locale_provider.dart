import 'dart:async' show unawaited;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../core/secure_store.dart';

/// App language. The initial locale follows the device (owner rule
/// 2026-10-02: Arabic phone → Arabic, English phone → English, anything
/// else → Arabic); the student's manual choice is saved in the secure
/// store and wins over the device on later launches.
class LocaleProvider extends ChangeNotifier {
  LocaleProvider({TokenStore? store, String? deviceLanguageCode})
    : _deviceLanguageCode = deviceLanguageCode ?? _platformLanguageCode() {
    _store = store;
    _locale = resolveLocale(saved: null, device: _deviceLanguageCode);
  }

  TokenStore? _store;
  final String _deviceLanguageCode;
  late Locale _locale;

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  static String _platformLanguageCode() {
    try {
      return PlatformDispatcher.instance.locale.languageCode;
    } catch (_) {
      return 'en';
    }
  }

  /// Owner language rule: a saved choice wins; otherwise the device
  /// language decides, with anything but English falling back to Arabic.
  static Locale resolveLocale({
    required String? saved,
    required String device,
  }) {
    if (saved == 'ar') return const Locale('ar');
    if (saved == 'en') return const Locale('en');
    if (device.startsWith('en')) return const Locale('en');
    if (device.startsWith('ar')) return const Locale('ar');
    return const Locale('ar');
  }

  /// Loads the saved choice, if any. `main()` awaits this before the first
  /// frame, so there is no flash of the wrong language.
  Future<void> load() async {
    final saved = await _store?.readLocale();
    final resolved = resolveLocale(saved: saved, device: _deviceLanguageCode);
    if (resolved != _locale) {
      _locale = resolved;
      notifyListeners();
    }
  }

  void setLocale(Locale newLocale) {
    if (_locale == newLocale) return;
    _locale = newLocale;
    unawaited(_store?.writeLocale(newLocale.languageCode));
    notifyListeners();
  }

  void toggleLocale() {
    if (_locale.languageCode == 'en') {
      _locale = const Locale('ar');
    } else {
      _locale = const Locale('en');
    }
    unawaited(_store?.writeLocale(_locale.languageCode));
    notifyListeners();
  }
}
