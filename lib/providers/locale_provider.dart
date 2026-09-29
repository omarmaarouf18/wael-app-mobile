import 'package:flutter/material.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  void setLocale(Locale newLocale) {
    if (_locale == newLocale) return;
    _locale = newLocale;
    notifyListeners();
  }

  void toggleLocale() {
    if (_locale.languageCode == 'en') {
      _locale = const Locale('ar');
    } else {
      _locale = const Locale('en');
    }
    notifyListeners();
  }
}
