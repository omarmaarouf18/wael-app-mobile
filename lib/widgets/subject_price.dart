import 'package:flutter/material.dart';

import '../core/price_format.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// The price of a subject the student does not own, shown only when the API
/// sent it (`price != null`; the server omits it unless
/// `EXPOSE_PRICE_TO_STUDENTS=true`, SPEC D3).
///
/// Owned subjects and a null price never reach this widget: the callers
/// render nothing (and no gap) instead. The row is label + formatted value
/// (`formatSubjectPrice`), never inside or on the WhatsApp/support button:
/// it lives in the subject header on detail and above the counts on cards.
class SubjectPriceTag extends StatelessWidget {
  const SubjectPriceTag({
    super.key,
    required this.amount,
    this.currency,
    required this.isArabic,
    this.compact = false,
  });

  final int amount;
  final String? currency;
  final bool isArabic;

  /// Smaller type for list cards; full size for the subject header.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = formatSubjectPrice(
      amount: amount,
      currency: currency,
      isArabic: isArabic,
    );
    final labelStyle =
        (compact
                ? AppTypography.bodyXs(isArabic: isArabic)
                : AppTypography.bodySm(isArabic: isArabic))
            .copyWith(color: AppColors.textMuted);
    final valueStyle =
        (compact
                ? AppTypography.bodyMd(isArabic: isArabic)
                : AppTypography.headlineSm(isArabic: isArabic))
            .copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            );

    return Row(
      children: [
        Flexible(
          child: Text(
            l10n.priceLabel,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
        const SizedBox(width: AppSpacing.spaceXs),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: valueStyle,
          ),
        ),
      ],
    );
  }
}
