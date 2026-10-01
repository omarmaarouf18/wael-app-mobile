import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Full-width hero art that dissolves into [AppColors.voidCanvas] at the
/// bottom (linear fade plus a radial vignette). Falls back to
/// [fallbackAsset], then to a flat surface, when an image fails to load.
///
/// Place it in a [Stack] under a `PositionedDirectional(top: 0, start: 0,
/// end: 0, child: HeroBackdrop(...))`.
class HeroBackdrop extends StatelessWidget {
  const HeroBackdrop({
    super.key,
    required this.imageAsset,
    this.fallbackAsset,
    this.heightFactor = 0.65,
    this.alignment = const Alignment(0, -0.6),
  });

  final String imageAsset;
  final String? fallbackAsset;

  /// Fraction of the screen height.
  final double heightFactor;
  final Alignment alignment;

  Widget _flat() => const ColoredBox(color: AppColors.surfaceLayer1);

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * heightFactor;

    Widget image(String asset, ImageErrorWidgetBuilder onError) => Image.asset(
      asset,
      fit: BoxFit.cover,
      alignment: alignment,
      errorBuilder: onError,
    );

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          image(
            imageAsset,
            (context, error, stackTrace) => fallbackAsset == null
                ? _flat()
                : image(fallbackAsset!, (ctx, err, st) => _flat()),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.25, 0.55, 0.85, 1.0],
                colors: [
                  AppColors.scrimBlack.withValues(alpha: 0.35),
                  Colors.transparent,
                  AppColors.voidCanvas.withValues(alpha: 0.55),
                  AppColors.voidCanvas.withValues(alpha: 0.95),
                  AppColors.voidCanvas,
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 0.85,
                colors: [
                  Colors.transparent,
                  AppColors.voidCanvas.withValues(alpha: 0.65),
                  AppColors.voidCanvas,
                ],
                stops: const [0.45, 0.75, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
