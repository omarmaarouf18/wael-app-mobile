import 'package:flutter/material.dart';

import '../core/theme.dart';

/// 16:10 hero image for a subject, fading into the canvas at the bottom, with
/// an optional dark tag (the term) at the top start corner. [fallbackAsset]
/// is shown when [imageAsset] cannot be loaded.
class SubjectHeroBanner extends StatelessWidget {
  const SubjectHeroBanner({
    super.key,
    required this.imageAsset,
    required this.fallbackAsset,
    this.tag,
  });

  final String imageAsset;
  final String fallbackAsset;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: Image.asset(
            imageAsset,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Image.asset(fallbackAsset, fit: BoxFit.cover),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const [0.0, 0.5, 1.0],
                colors: [
                  AppColors.voidCanvas,
                  AppColors.voidCanvas.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        if (tag != null)
          PositionedDirectional(
            top: 12,
            start: 16,
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.scrimBlack.withValues(alpha: 0.8),
                borderRadius: AppRadius.radiusXs,
                border: Border.all(color: AppColors.glassHairline),
              ),
              child: Text(
                AppTypography.uppercaseLabel(tag!),
                style: AppTypography.labelSm().copyWith(
                  fontSize: 9,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
