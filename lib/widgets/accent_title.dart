import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Section title with a short crimson bar at the start edge. Titles are
/// upper-cased through [AppTypography.uppercaseLabel].
class AccentTitle extends StatelessWidget {
  const AccentTitle({
    super.key,
    required this.title,
    this.color = AppColors.textPrimary,
    this.barHeight = 14,
    this.trailing,
  });

  final String title;
  final Color color;
  final double barHeight;

  /// Optional widget at the end edge (a count badge, a hint).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;

    return Row(
      children: [
        Container(
          width: 3,
          height: barHeight,
          decoration: const BoxDecoration(
            color: AppColors.crimson,
            borderRadius: AppRadius.radiusPill,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              AppTypography.uppercaseLabel(title),
              style: AppTypography.labelSm(isArabic: isArabic).copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: isArabic ? 0 : 1.2,
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
