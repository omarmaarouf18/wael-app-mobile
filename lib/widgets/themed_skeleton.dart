import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Skeleton placeholders for loading lists (home, courses, subject detail).
///
/// Design-system widget: only [AppColors], [AppSpacing] and [AppRadius]
/// tokens, no raw colors. Static placeholders (no animation package); the
/// semantics label marks the region as loading for screen readers.
class ThemedSkeleton extends StatelessWidget {
  const ThemedSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = AppRadius.radiusSm,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: borderRadius,
        border: Border.all(color: AppColors.subtleHairline),
      ),
    );
  }
}

/// Skeleton for a subject/card row: a thumbnail block plus two text lines.
class ThemedSkeletonCard extends StatelessWidget {
  const ThemedSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Container(
        padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.subtleHairline),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ThemedSkeleton(width: 64, height: 64),
            SizedBox(width: AppSpacing.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ThemedSkeleton(width: 160, height: 14),
                  SizedBox(height: AppSpacing.spaceSm),
                  ThemedSkeleton(height: 12),
                  SizedBox(height: AppSpacing.spaceXs),
                  ThemedSkeleton(width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton list shown while the home, courses or subject detail lists load.
class ThemedSkeletonList extends StatelessWidget {
  const ThemedSkeletonList({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      liveRegion: true,
      child: Column(
        children: [
          for (var i = 0; i < itemCount; i++) ...[
            const ThemedSkeletonCard(),
            const SizedBox(height: AppSpacing.spaceSm),
          ],
        ],
      ),
    );
  }
}
