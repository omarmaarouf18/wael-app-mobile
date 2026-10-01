import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/instructor_profile.dart';
import 'app_badge.dart';
import 'themed_card.dart';

/// Card presenting the academy director: portrait, name with a founder tag,
/// title, credential chips and an expandable biography.
class InstructorDossierCard extends StatelessWidget {
  const InstructorDossierCard({
    super.key,
    required this.profile,
    required this.bioExpanded,
    required this.onToggleBio,
  });

  final InstructorProfile profile;
  final bool bioExpanded;
  final VoidCallback onToggleBio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    final bioStyle = AppTypography.bodySm(
      isArabic: isArabic,
    ).copyWith(color: AppColors.textSecondary, height: 1.45, fontSize: 12);
    final bio = profile.localizedBio(isArabic);

    return ThemedCard(
      padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(
                    color: AppColors.crimson.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  image: DecorationImage(
                    image: AssetImage(profile.imagePath),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
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
                        Expanded(
                          child: Text(
                            profile.localizedName(isArabic),
                            style: AppTypography.headlineSm(isArabic: isArabic)
                                .copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                          ),
                        ),
                        AppBadge(
                          label: isArabic ? 'المؤسس' : 'FOUNDER',
                          accent: true,
                          fontSize: 9,
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.localizedTitle(isArabic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm(isArabic: isArabic).copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceSm),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final cred in profile.localizedCredentials(isArabic))
                AppBadge(
                  label: cred,
                  subtle: true,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceSm),
          AnimatedCrossFade(
            firstChild: Text(
              bio,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: bioStyle,
            ),
            secondChild: Text(bio, style: bioStyle),
            crossFadeState: bioExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: AppMotion.durationNormal,
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: onToggleBio,
            borderRadius: AppRadius.radiusXs,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    bioExpanded ? l10n.showLess : l10n.readMore,
                    style: AppTypography.labelSm(isArabic: isArabic).copyWith(
                      color: AppColors.crimson,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    bioExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: AppColors.crimson,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
