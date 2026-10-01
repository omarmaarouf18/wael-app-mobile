import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import 'app_badge.dart';
import 'icon_tile.dart';
import 'themed_panel.dart';

/// Summary card above the subject list: the selected level, its study type,
/// and how many subjects it has.
class CatalogLevelHeader extends StatelessWidget {
  const CatalogLevelHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.countLabel,
  });

  final String title;
  final String subtitle;
  final String countLabel;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;

    return ThemedPanel(
      tone: PanelTone.inset,
      borderRadius: AppRadius.radiusLg,
      padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
      child: Row(
        children: [
          IconTile(
            icon: Icons.account_balance,
            iconColor: AppColors.crimson,
            background: AppColors.crimson.withValues(alpha: 0.15),
            borderColor: AppColors.crimson.withValues(alpha: 0.3),
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: AppSpacing.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.headlineSm(
                    isArabic: isArabic,
                  ).copyWith(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyXs(isArabic: isArabic),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.spaceSm),
          AppBadge(
            label: countLabel,
            pill: true,
            fontSize: 11,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
          ),
        ],
      ),
    );
  }
}
