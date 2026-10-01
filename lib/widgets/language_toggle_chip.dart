import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Small pill that switches the app language. [label] names the language it
/// switches TO, in that language ("English" / "العربية").
class LanguageToggleChip extends StatelessWidget {
  const LanguageToggleChip({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusPill,
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.spaceMd,
            vertical: AppSpacing.spaceXs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceLayer1.withValues(alpha: 0.85),
            borderRadius: AppRadius.radiusPill,
            border: Border.all(color: AppColors.subtleHairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.language,
                size: AppIconSize.xs,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.spaceXs),
              Text(
                label,
                style: AppTypography.labelSm(
                  isArabic: isArabic,
                ).copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
