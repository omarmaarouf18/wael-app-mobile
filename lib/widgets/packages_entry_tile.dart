import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import 'icon_tile.dart';
import 'themed_card.dart';

/// The iOS entry point to the packages screen (issue #58), shown on Home and
/// Courses. The caller renders it only behind `StorePolicy.iapEnabled`.
class PackagesEntryTile extends StatelessWidget {
  const PackagesEntryTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    return Semantics(
      button: true,
      label: '${l10n.iapPackagesTitle}. ${l10n.iapEntrySubtitle}',
      excludeSemantics: true,
      child: ThemedCard(
        onTap: onTap,
        borderColor: AppColors.prominentBorder,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.spaceMd,
          vertical: AppSpacing.spaceMd,
        ),
        child: Row(
          children: [
            const IconTile(
              icon: Icons.inventory_2_outlined,
              iconColor: AppColors.textPrimary,
              background: AppColors.crimsonTinted,
              size: 44,
              borderColor: AppColors.activeBorder,
            ),
            const SizedBox(width: AppSpacing.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.iapPackagesTitle,
                    style: AppTypography.headlineSm(isArabic: isArabic),
                  ),
                  const SizedBox(height: AppSpacing.space2xs),
                  Text(
                    l10n.iapEntrySubtitle,
                    style: AppTypography.bodySm(isArabic: isArabic),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.spaceSm),
            Icon(
              isArabic ? Icons.chevron_left : Icons.chevron_right,
              size: AppIconSize.md,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
