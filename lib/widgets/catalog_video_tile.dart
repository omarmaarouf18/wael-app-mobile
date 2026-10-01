import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/academy_catalog.dart';
import 'themed_card.dart';

/// Row for one lesson video of a subject. A [locked] video (not owned, or the
/// server sent no video id) shows a lock instead of the play arrow. The tile
/// never knows or builds a video URL; it only reports taps.
class CatalogVideoTile extends StatelessWidget {
  const CatalogVideoTile({
    super.key,
    required this.video,
    required this.locked,
    required this.onTap,
  });

  final AcademyVideo video;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    final description = video.description.resolve(isArabic);

    return ThemedCard(
      onTap: onTap,
      padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: AppRadius.radiusMd,
            ),
            child: Icon(
              locked ? Icons.lock_outline : Icons.play_circle_outline,
              color: locked ? AppColors.textMuted : AppColors.crimson,
            ),
          ),
          const SizedBox(width: AppSpacing.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title.resolve(isArabic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm(isArabic: isArabic).copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description.isEmpty
                      ? l10n.videoNumber(video.position)
                      : description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSm(isArabic: isArabic).copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: isArabic ? 0 : null,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            locked ? Icons.lock_outline : Icons.play_arrow,
            size: 20,
            color: locked ? AppColors.textMuted : AppColors.crimson,
          ),
        ],
      ),
    );
  }
}
