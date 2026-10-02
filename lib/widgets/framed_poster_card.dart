import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A poster in a rounded card with a 1px crimson-tinted border and a soft
/// crimson glow. The whole image is shown ([BoxFit.contain], never cropped).
///
/// The card is sized from the poster's [aspectRatio] (width over height), so
/// the frame hugs the image. It is at most [maxHeightFraction] of the screen
/// height tall, and never wider than the space it is given.
class FramedPosterCard extends StatelessWidget {
  const FramedPosterCard({
    super.key,
    required this.imageAsset,
    required this.aspectRatio,
    this.maxHeightFraction = 0.55,
    this.semanticLabel,
  });

  final String imageAsset;

  /// Width over height of the image.
  final double aspectRatio;

  /// Upper bound of the card height as a fraction of the screen height.
  final double maxHeightFraction;

  /// Announced to screen readers; null leaves the image unlabelled.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return LayoutBuilder(
      builder: (context, constraints) {
        var height = screenHeight * maxHeightFraction;
        var width = height * aspectRatio;
        if (constraints.hasBoundedWidth && width > constraints.maxWidth) {
          width = constraints.maxWidth;
          height = width / aspectRatio;
        }

        return Center(
          child: Semantics(
            image: true,
            label: semanticLabel,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: AppColors.scrimBlack,
                borderRadius: AppRadius.radiusXl,
                border: Border.all(
                  color: AppColors.crimson.withValues(alpha: 0.35),
                  width: 1,
                ),
                boxShadow: AppElevation.crimsonGlow,
              ),
              // One pixel smaller than the frame so the border stays visible.
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl - 1),
                child: Image.asset(
                  imageAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: AppColors.surfaceLayer1),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
