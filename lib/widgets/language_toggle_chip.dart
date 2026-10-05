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

    // 48x48 dp min tap target around a compact pill visual. The Align
    // factors keep the box hugging the visual (no full-width stretch) while
    // centering it in the target. The label names the language, so screen
    // readers are covered.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusPill,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1.0,
            heightFactor: 1.0,
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
                mainAxisAlignment: MainAxisAlignment.center,
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
        ),
      ),
    );
  }
}
