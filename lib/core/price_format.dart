import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

/// Formats a subject price exactly as the server sent it.
///
/// The academy API sends `price` (whole EGP by SPEC D2) and `currency`
/// (`"EGP"`) on subject list items and subject detail only when the server
/// env `EXPOSE_PRICE_TO_STUDENTS=true`; otherwise both are absent and the
/// callers show nothing. This helper never invents a price: it only renders
/// the pair it is given.
///
/// Digits stay Western/ASCII in both languages, like the counts the app
/// already shows (`subjectsCount`, `itemsCount`). `"EGP"` renders as `ج.م`
/// in Arabic and `EGP` in English; an unknown code is shown raw after the
/// number so nothing is silently mistranslated.
String formatSubjectPrice({
  required int amount,
  required String? currency,
  required bool isArabic,
}) {
  final code = (currency ?? '').trim();
  if (code == 'EGP') {
    return isArabic ? '$amount ج.م' : 'EGP $amount';
  }
  if (code.isEmpty) return '$amount';
  return isArabic ? '$amount $code' : '$code $amount';
}

/// Whether a subject's price may render (amended 2026-11-05, Part D):
///
/// - iOS never shows prices (unchanged, per the iOS store decision).
/// - Android and other platforms show a subject's price only when its
///   effective setting is show, which the server communicates by sending
///   a non-null [price] on the unlocked subject.
/// - Owned subjects or a null price (effective setting hide, follow_global
///   with global off, or EXPOSE_PRICE_TO_STUDENTS=false) hide the price.
/// - An explicit [showPrices] = false override still hides the price if passed.
bool shouldShowSubjectPrice({
  required bool owned,
  required int? price,
  bool? showPrices,
  TargetPlatform? platform,
}) {
  final p = platform ?? defaultTargetPlatform;
  if (p == TargetPlatform.iOS) {
    return false;
  }
  if (showPrices == false) {
    return false;
  }
  return !owned && price != null;
}
