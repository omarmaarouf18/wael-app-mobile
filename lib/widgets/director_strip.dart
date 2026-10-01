import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import 'status_dot.dart';
import 'themed_card.dart';

/// Compact card naming the academy director on a subject: round portrait,
/// name with a crimson dot, and a one-line tagline.
class DirectorStrip extends StatelessWidget {
  const DirectorStrip({
    super.key,
    required this.name,
    required this.tagline,
    required this.imageAsset,
  });

  final String name;
  final String tagline;
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
              image: DecorationImage(
                image: AssetImage(imageAsset),
                fit: BoxFit.cover,
              ),
            ),
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
                const SizedBox(height: 2),
                Text(
                  tagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyXs(isArabic: isArabic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
