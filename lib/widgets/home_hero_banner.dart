import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Home hero: character art fading in from the start edge, a fade into the
/// canvas at the bottom, and headline, subheadline and an "Explore courses"
/// button at the start edge. Everything is directional, so the art sits at
/// the end edge (right in English, left in Arabic).
class HomeHeroBanner extends StatelessWidget {
  const HomeHeroBanner({super.key, required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final direction = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final heroHeight = (screenWidth * 0.85).clamp(320.0, 390.0);
        final imageWidth = (screenWidth * 0.62).clamp(190.0, 270.0);

        // Min height, never fixed: at large text sizes the copy grows the
        // hero instead of clipping.
        return ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: heroHeight,
            maxWidth: screenWidth,
          ),
          child: SizedBox(
            width: screenWidth,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Character art at the end edge, fading in from its start side.
                PositionedDirectional(
                  top: 0,
                  bottom: 0,
                  end: 0,
                  width: imageWidth,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: AlignmentDirectional.centerStart,
                        end: AlignmentDirectional.centerEnd,
                        stops: [0.0, 0.35, 1.0],
                        colors: [
                          Colors.transparent,
                          Color(0x99000000),
                          AppColors.scrimBlack,
                        ],
                      ).createShader(rect, textDirection: direction);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      AppConstants.imgHomeHero,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        AppConstants.imgCharacterArt,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (ctx, err, st) => const ColoredBox(
                          color: AppColors.surfaceContainerLow,
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom dissolution into the canvas.
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: 0,
                  height: 60,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.voidCanvas,
                          AppColors.voidCanvas.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                // Text contrast gradient across the full width.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.centerStart,
                        end: AlignmentDirectional.centerEnd,
                        stops: const [0.0, 0.45, 0.8, 1.0],
                        colors: [
                          AppColors.voidCanvas,
                          AppColors.voidCanvas.withValues(alpha: 0.95),
                          AppColors.voidCanvas.withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Headline, subheadline and call to action.
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.marginMobile,
                    vertical: AppSpacing.spaceMd,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: (screenWidth * 0.60).clamp(200.0, 290.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 2,
                            color: AppColors.crimson,
                            margin: const EdgeInsetsDirectional.only(
                              bottom: AppSpacing.spaceMd,
                            ),
                          ),
                          Semantics(
                            header: true,
                            child: Text(
                              l10n.heroHeadline,
                              style: AppTypography.heroHeadline(
                                isArabic: l10n.isArabic,
                                compact: screenWidth < 360,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.spaceSm),
                          Text(
                            l10n.heroSubheadline,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySm(
                              isArabic: l10n.isArabic,
                            ).copyWith(height: 1.4, fontSize: 12),
                          ),
                          const SizedBox(height: AppSpacing.spaceLg),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onExplore,
                              borderRadius: AppRadius.radiusLg,
                              child: Ink(
                                padding: const EdgeInsetsDirectional.symmetric(
                                  horizontal: AppSpacing.spaceLg,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.crimson,
                                  borderRadius: AppRadius.radiusLg,
                                  boxShadow: AppElevation.crimsonGlow,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        l10n.exploreCourses,
                                        style:
                                            AppTypography.labelSm(
                                              isArabic: l10n.isArabic,
                                            ).copyWith(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: l10n.isArabic
                                                  ? 0
                                                  : 1.2,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.spaceSm),
                                    // Mirrors automatically in RTL.
                                    const Icon(
                                      Icons.arrow_forward,
                                      size: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
