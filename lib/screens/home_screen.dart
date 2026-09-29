import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../l10n/app_localizations.dart';
import '../providers/home_provider.dart';
import '../widgets/themed_card.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onExploreCourses;

  const HomeScreen({super.key, this.onExploreCourses});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final home = Provider.of<HomeProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.voidCanvas,
      body: RefreshIndicator(
        color: AppColors.crimson,
        backgroundColor: AppColors.surfaceElevated,
        onRefresh: () => home.refreshDashboard(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. RESPONSIVE HERO SECTION with Adaptive Proportions & Dissolution
              LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  final heroHeight = (screenWidth * 0.85).clamp(320.0, 390.0);
                  final isRtl = l10n.isArabic;
                  final imageWidth = (screenWidth * 0.62).clamp(190.0, 270.0);

                  return SizedBox(
                    height: heroHeight,
                    width: screenWidth,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Character Art Image (trailing alignment: left in RTL, right in LTR)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: isRtl ? 0 : null,
                          right: isRtl ? null : 0,
                          width: imageWidth,
                          child: ShaderMask(
                            shaderCallback: (rect) {
                              return LinearGradient(
                                begin: isRtl
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                end: isRtl
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                stops: const [0.0, 0.35, 1.0],
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.6),
                                  Colors.black,
                                ],
                              ).createShader(rect);
                            },
                            blendMode: BlendMode.dstIn,
                            child: Image.asset(
                              AppConstants.imgHomeHero,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              errorBuilder: (context, error, stackTrace) =>
                                  Image.asset(
                                    AppConstants.imgCharacterArt,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.topCenter,
                                    errorBuilder: (ctx, err, st) => Container(
                                      color: AppColors.surfaceContainerLow,
                                    ),
                                  ),
                            ),
                          ),
                        ),

                        // Bottom dissolution gradient into voidCanvas
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 60,
                          child: Container(
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

                        // Text Background Gradient across full width for contrast
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: isRtl
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                end: isRtl
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
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

                        // Hero Text & CTA
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.marginMobile,
                            vertical: AppSpacing.spaceMd,
                          ),
                          child: Align(
                            alignment: isRtl
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: (screenWidth * 0.60).clamp(
                                  200.0,
                                  290.0,
                                ),
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
                                    margin: const EdgeInsets.only(
                                      bottom: AppSpacing.spaceMd,
                                    ),
                                  ),
                                  Text(
                                    l10n.heroHeadline,
                                    style:
                                        AppTypography.headlineLg(
                                          isArabic: l10n.isArabic,
                                        ).copyWith(
                                          fontSize: screenWidth < 360 ? 22 : 26,
                                          fontWeight: FontWeight.w800,
                                          height: 1.15,
                                          letterSpacing: -0.5,
                                        ),
                                  ),
                                  const SizedBox(height: AppSpacing.spaceSm),
                                  Text(
                                    l10n.heroSubheadline,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        AppTypography.bodySm(
                                          isArabic: l10n.isArabic,
                                        ).copyWith(
                                          color: AppColors.textMuted,
                                          height: 1.4,
                                          fontSize: 12,
                                        ),
                                  ),
                                  const SizedBox(height: AppSpacing.spaceLg),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        if (onExploreCourses != null) {
                                          onExploreCourses!();
                                        } else {
                                          Navigator.of(
                                            context,
                                          ).pushNamed('/courses');
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.lg,
                                      ),
                                      child: Ink(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.spaceLg,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.crimson,
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.lg,
                                          ),
                                          boxShadow: AppElevation.crimsonGlow,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              l10n.exploreCourses,
                                              style:
                                                  AppTypography.labelSm(
                                                    isArabic: l10n.isArabic,
                                                  ).copyWith(
                                                    color:
                                                        AppColors.textPrimary,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 1.2,
                                                  ),
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.spaceSm,
                                            ),
                                            Icon(
                                              isRtl
                                                  ? Icons.arrow_back
                                                  : Icons.arrow_forward,
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
                  );
                },
              ),

              // 2. ACADEMY DIRECTOR & INSTRUCTOR SECTION
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: AppSpacing.spaceSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 3,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.crimson,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.instructorSectionTitle,
                          style: AppTypography.labelSm(isArabic: l10n.isArabic)
                              .copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.spaceSm),

                    // Instructor Dossier Card
                    ThemedCard(
                      padding: const EdgeInsets.all(AppSpacing.spaceMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Portrait Image with crimson border
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  border: Border.all(
                                    color: AppColors.crimson.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: 1.5,
                                  ),
                                  image: DecorationImage(
                                    image: AssetImage(
                                      home.instructor.imagePath,
                                    ),
                                    fit: BoxFit.cover,
                                    alignment: Alignment.topCenter,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.spaceMd),

                              // Name & Title
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            home.instructor.localizedName(
                                              l10n.isArabic,
                                            ),
                                            style:
                                                AppTypography.headlineSm(
                                                  isArabic: l10n.isArabic,
                                                ).copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 16,
                                                  color: AppColors.textPrimary,
                                                ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.crimson.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.xs,
                                            ),
                                            border: Border.all(
                                              color: AppColors.crimson
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            l10n.isArabic
                                                ? 'المؤسس'
                                                : 'FOUNDER',
                                            style: AppTypography.labelSm()
                                                .copyWith(
                                                  color: AppColors.crimson,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      home.instructor.localizedTitle(
                                        l10n.isArabic,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          AppTypography.bodySm(
                                            isArabic: l10n.isArabic,
                                          ).copyWith(
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

                          // Credentials Badges
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: home.instructor
                                .localizedCredentials(l10n.isArabic)
                                .map(
                                  (cred) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.xs,
                                      ),
                                      border: Border.all(
                                        color: AppColors.subtleHairline,
                                      ),
                                    ),
                                    child: Text(
                                      cred,
                                      style:
                                          AppTypography.labelSm(
                                            isArabic: l10n.isArabic,
                                          ).copyWith(
                                            color: AppColors.textMuted,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: AppSpacing.spaceSm),

                          // Expandable Biography
                          AnimatedCrossFade(
                            firstChild: Text(
                              home.instructor.localizedBio(l10n.isArabic),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  AppTypography.bodySm(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.45,
                                    fontSize: 12,
                                  ),
                            ),
                            secondChild: Text(
                              home.instructor.localizedBio(l10n.isArabic),
                              style:
                                  AppTypography.bodySm(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.45,
                                    fontSize: 12,
                                  ),
                            ),
                            crossFadeState: home.isBioExpanded
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: AppMotion.durationNormal,
                          ),
                          const SizedBox(height: 4),

                          // Read More / Show Less Toggle
                          InkWell(
                            onTap: () => home.toggleBioExpansion(),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    home.isBioExpanded
                                        ? l10n.showLess
                                        : l10n.readMore,
                                    style:
                                        AppTypography.labelSm(
                                          isArabic: l10n.isArabic,
                                        ).copyWith(
                                          color: AppColors.crimson,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    home.isBioExpanded
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
                    ),
                  ],
                ),
              ),

              // 2. CONTINUE LEARNING SECTION
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: AppSpacing.spaceSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.continueLearning,
                          style: AppTypography.labelSm(isArabic: l10n.isArabic)
                              .copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.spaceSm),

                    // Active Course Card
                    ThemedCard(
                      padding: const EdgeInsets.all(AppSpacing.spaceMd),
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          '/course-details',
                          arguments: 'architectural-discipline',
                        );
                      },
                      child: Row(
                        children: [
                          // Course Thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: Image.asset(
                                AppConstants.imgCourseStrategic,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: Colors.black54,
                                      child: const Icon(
                                        Icons.school,
                                        color: AppColors.crimson,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.spaceMd),

                          // Titles & Progress
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.isArabic
                                      ? 'البلاغة الاستراتيجية وفن الصمت'
                                      : 'Strategic Rhetoric & Discourse',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      AppTypography.bodyMd(
                                        isArabic: l10n.isArabic,
                                      ).copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.isArabic
                                      ? 'الدرس ٠٧ • قوة الصمت والتوقفات'
                                      : 'Lesson 07 • The Power of Pauses',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      AppTypography.bodySm(
                                        isArabic: l10n.isArabic,
                                      ).copyWith(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.spaceSm),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.pill,
                                        ),
                                        child: Container(
                                          height: 4,
                                          color: AppColors.subtleHairline,
                                          child: FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: 0.68,
                                            child: Container(
                                              color: AppColors.crimson,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.spaceSm),
                                    Text(
                                      '68%',
                                      style: AppTypography.labelSm().copyWith(
                                        color: AppColors.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.spaceSm),

                          // Resume Button
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHigh,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.subtleHairline,
                              ),
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              size: 18,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. MY COURSES SECTION
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: AppSpacing.spaceSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.myCourses,
                          style: AppTypography.labelSm(isArabic: l10n.isArabic)
                              .copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (onExploreCourses != null) {
                              onExploreCourses!();
                            } else {
                              Navigator.of(context).pushNamed('/courses');
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.viewAll,
                                style:
                                    AppTypography.labelSm(
                                      isArabic: l10n.isArabic,
                                    ).copyWith(
                                      color: AppColors.textMuted,
                                      fontSize: 10,
                                    ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.arrow_forward,
                                size: 12,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.spaceSm),

                    // Course Card 1: Psychology of Composure
                    ThemedCard(
                      padding: const EdgeInsets.all(AppSpacing.spaceMd),
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          '/course-details',
                          arguments: 'psychology-composure',
                        );
                      },
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Image.asset(
                                AppConstants.imgCoursePsychology,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(color: Colors.black54),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.isArabic
                                      ? 'سيكولوجية الثبات وضبط النفس'
                                      : 'Psychology of Composure',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodyMd(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.isArabic
                                      ? '١٢ درساً • قيد المتابعة'
                                      : '12 Lessons • In Progress',
                                  style:
                                      AppTypography.bodySm(
                                        isArabic: l10n.isArabic,
                                      ).copyWith(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: 90,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.pill,
                                    ),
                                    child: Container(
                                      height: 3.5,
                                      color: AppColors.subtleHairline,
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: 0.45,
                                        child: Container(
                                          color: AppColors.crimson,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spaceSm),

                    // Course Card 2: Executive Protocol & Poise
                    ThemedCard(
                      padding: const EdgeInsets.all(AppSpacing.spaceMd),
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          '/course-details',
                          arguments: 'architectural-discipline',
                        );
                      },
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Image.asset(
                                AppConstants.imgCourseExecutive,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(color: Colors.black54),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.isArabic
                                      ? 'البروتوكول التنفيذي والوقار'
                                      : 'Executive Protocol & Poise',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodyMd(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.isArabic
                                      ? '٨ دروس • تم الاشتراك'
                                      : '8 Lessons • Enrolled',
                                  style:
                                      AppTypography.bodySm(
                                        isArabic: l10n.isArabic,
                                      ).copyWith(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.readyToStart,
                                  style:
                                      AppTypography.labelSm(
                                        isArabic: l10n.isArabic,
                                      ).copyWith(
                                        color: AppColors.crimson,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 4. UPCOMING EVENT SECTION
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: AppSpacing.spaceSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.upcoming,
                          style: AppTypography.labelSm(isArabic: l10n.isArabic)
                              .copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.spaceSm),

                    // Event Card with RSVP action
                    ThemedCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // Date box
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: AppColors.subtleHairline,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  l10n.isArabic ? 'خميس' : 'THU',
                                  style: AppTypography.labelSm().copyWith(
                                    color: AppColors.crimson,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Text(
                                  '24',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.spaceMd),

                          // Event title & time
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.crisisSeminar,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      AppTypography.bodyMd(
                                        isArabic: l10n.isArabic,
                                      ).copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.todayGmt,
                                  style:
                                      AppTypography.bodySm(
                                        isArabic: l10n.isArabic,
                                      ).copyWith(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.spaceSm),

                          // RSVP Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                home.toggleRsvp();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.surfaceElevated,
                                    duration: const Duration(seconds: 2),
                                    content: Text(
                                      home.isRsvpConfirmed
                                          ? (l10n.isArabic
                                                ? 'تم تأكيد حضورك للندوة بنجاح ✓'
                                                : 'RSVP confirmed for Crisis Communication Seminar ✓')
                                          : (l10n.isArabic
                                                ? 'تم إلغاء تأكيد الحضور'
                                                : 'RSVP status updated'),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              child: AnimatedContainer(
                                duration: AppMotion.durationFast,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: home.isRsvpConfirmed
                                      ? AppColors.statusApprovedBg
                                      : AppColors.crimson,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                  border: Border.all(
                                    color: home.isRsvpConfirmed
                                        ? AppColors.statusApproved
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      home.isRsvpConfirmed
                                          ? Icons.check
                                          : Icons.event_available,
                                      size: 13,
                                      color: home.isRsvpConfirmed
                                          ? AppColors.statusApproved
                                          : AppColors.textPrimary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      home.isRsvpConfirmed
                                          ? (l10n.isArabic
                                                ? 'مؤكد ✓'
                                                : 'CONFIRMED')
                                          : l10n.rsvp,
                                      style: AppTypography.labelSm().copyWith(
                                        color: home.isRsvpConfirmed
                                            ? AppColors.statusApproved
                                            : AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
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
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.space3xl),
            ],
          ),
        ),
      ),
    );
  }
}
