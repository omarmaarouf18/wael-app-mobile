import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Small bordered label: subject code, term, counts.
///
/// [accent] tints it crimson; otherwise it is a neutral elevated chip.
/// [pill] uses fully rounded corners instead of the small radius.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.accent = false,
    this.pill = false,
    this.fontSize = 10,
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: 7,
      vertical: 3,
    ),
  });

  final String label;
  final bool accent;
  final bool pill;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    final radius = pill ? AppRadius.radiusPill : AppRadius.radiusXs;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: accent
            ? AppColors.crimson.withValues(alpha: 0.15)
            : AppColors.surfaceElevated,
        borderRadius: radius,
        border: Border.all(
          color: accent
              ? AppColors.crimson.withValues(alpha: 0.3)
              : AppColors.subtleHairline,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.labelSm(isArabic: isArabic).copyWith(
          color: accent ? AppColors.crimson : AppColors.textSecondary,
          fontSize: fontSize,
          fontWeight: accent ? FontWeight.w800 : FontWeight.w600,
          // Spacing breaks joined Arabic letterforms.
          letterSpacing: isArabic ? 0 : (accent ? 1.0 : null),
        ),
      ),
    );
  }
}
