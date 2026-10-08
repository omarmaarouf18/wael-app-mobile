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
