import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import 'status_dot.dart';
import 'themed_card.dart';

/// Compact card naming the academy director on a subject: round portrait (a
/// neutral icon when there is none), name with a crimson dot, and a one-line
/// tagline that is left out when empty.
class DirectorStrip extends StatelessWidget {
  const DirectorStrip({
    super.key,
    required this.name,
    this.tagline = '',
    this.imageAsset = '',
  });

  final String name;
  final String tagline;

  /// Asset path of the portrait; empty shows a person icon.
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;

    return ThemedCard(
      padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.glassHairline),
              image: imageAsset.isEmpty
                  ? null
                  : DecorationImage(
                      // The art is 1024 x 1536; decode it small.
                      image: ResizeImage(AssetImage(imageAsset), width: 144),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
            ),
            child: imageAsset.isEmpty
                ? const Icon(
                    Icons.person_outline,
                    size: 24,
                    color: AppColors.textMuted,
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMd(isArabic: isArabic)
                            .copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const StatusDot(size: 6),
                  ],
                ),
                if (tagline.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    tagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyXs(isArabic: isArabic),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
