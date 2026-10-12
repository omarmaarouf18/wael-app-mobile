import 'package:flutter_test/flutter_test.dart';

import 'widget_layer_harness.dart';

// Owner decision 2026-10-12: the app says "الأكاديمية" / "academy" where it
// said "السنتر" / "center" (same change as the admin console). Labels only:
// getters and the app-config JSON field `center` are unchanged.
void main() {
  for (final (name, locale, _) in kLocales) {
    final l10n = l10nFor(locale);
    final ar = locale.languageCode == 'ar';

    test('[$name] activation wording names the academy, never the center', () {
      final texts = [
        ...l10n.termsSummaryBullets,
        l10n.contactSupportToActivate,
      ];
      for (final t in texts) {
        expect(t, isNot(contains('سنتر')));
        expect(t.toLowerCase(), isNot(contains('center')));
      }
      expect(
        l10n.termsSummaryBullets,
        contains(
          ar
              ? 'تفعيل المواد يتم من خلال الأكاديمية.'
              : 'Subjects are activated through the academy.',
        ),
      );
      expect(
        l10n.contactSupportToActivate,
        ar
            ? 'المادة دي بتتفعّل من خلال الأكاديمية. تواصل مع الدعم لتفعيلها.'
            : 'This subject is activated by the academy. Contact support to activate it.',
      );
    });
  }
}
