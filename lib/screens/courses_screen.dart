import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/courses_provider.dart';
import '../models/subject.dart';
import '../widgets/themed_card.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final coursesProvider = Provider.of<CoursesProvider>(context);
    final subjects = coursesProvider.currentSubjects;
    final currentLevel = coursesProvider.currentAcademicLevel;

    return Scaffold(
      backgroundColor: AppColors.voidCanvas,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. SEARCH BAR
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.marginMobile,
                right: AppSpacing.marginMobile,
                top: AppSpacing.spaceMd,
                bottom: AppSpacing.spaceSm,
              ),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.subtleHairline),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spaceMd,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.spaceSm),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: AppTypography.bodyMd(
                          isArabic: l10n.isArabic,
                        ).copyWith(color: AppColors.textPrimary),
                        onChanged: (val) => coursesProvider.setSearchQuery(val),
                        cursorColor: AppColors.crimson,
                        decoration: InputDecoration(
                          hintText: l10n.searchCoursesHint,
                          hintStyle: AppTypography.bodyMd(
                            isArabic: l10n.isArabic,
                          ).copyWith(color: AppColors.textTertiary),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        color: AppColors.textTertiary,
                        onPressed: () {
                          _searchController.clear();
                          coursesProvider.clearSearch();
                        },
                      ),
                  ],
                ),
              ),
            ),

            // 2. EDUCATION TYPE SELECTOR
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
                vertical: AppSpacing.spaceXs,
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.crimson,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.educationType.toUpperCase(),
                    style: AppTypography.labelSm(isArabic: l10n.isArabic)
                        .copyWith(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Education Types Horizontal List
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                ),
                itemCount: coursesProvider.educationCategories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = coursesProvider.educationCategories[index];
                  final isSelected =
                      cat.id == coursesProvider.selectedEducationType;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => coursesProvider.setEducationType(cat.id),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: AnimatedContainer(
                        duration: AppMotion.durationFast,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.surfaceElevated
                              : AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.crimson
                                : AppColors.subtleHairline,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? AppElevation.crimsonGlow
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat.icon,
                              size: 16,
                              color: isSelected
                                  ? AppColors.crimson
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              cat.localizedName(l10n.isArabic),
                              style:
                                  AppTypography.labelSm(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(
                                    color: isSelected
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.spaceSm),

            // 3. ACADEMIC YEAR / LEVEL SELECTOR
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
                vertical: AppSpacing.spaceXs,
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.crimson,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.academicYearLevel.toUpperCase(),
                    style: AppTypography.labelSm(isArabic: l10n.isArabic)
                        .copyWith(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Academic Levels Horizontal Track
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                ),
                itemCount: coursesProvider.availableLevels.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final lvl = coursesProvider.availableLevels[index];
                  final isSelected =
                      lvl.id == coursesProvider.selectedAcademicLevel;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => coursesProvider.setAcademicLevel(lvl.id),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: AnimatedContainer(
                        duration: AppMotion.durationFast,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.crimson
                              : AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.crimson
                                : AppColors.subtleHairline,
                          ),
                        ),
                        child: Text(
                          lvl.localizedName(l10n.isArabic),
                          style: AppTypography.labelSm(isArabic: l10n.isArabic)
                              .copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 12,
                              ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.spaceSm),

            // 4. LEVEL HEADER & CONTEXTUAL SUMMARY
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
                vertical: AppSpacing.spaceSm,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.spaceMd),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.subtleHairline),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.crimson.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.crimson.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.account_balance,
                        color: AppColors.crimson,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentLevel.localizedName(l10n.isArabic),
                            style:
                                AppTypography.headlineSm(
                                  isArabic: l10n.isArabic,
                                ).copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentLevel.localizedSubtitle(l10n.isArabic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySm(isArabic: l10n.isArabic)
                                .copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.subtleHairline),
                      ),
                      child: Text(
                        '${subjects.length} ${l10n.isArabic ? "مواد" : "Subjects"}',
                        style: AppTypography.labelSm().copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. SUBJECTS SECTION HEADER
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
                vertical: AppSpacing.spaceXs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.subjectEntity.toUpperCase(),
                    style: AppTypography.labelSm(isArabic: l10n.isArabic)
                        .copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                  ),
                  Text(
                    l10n.curriculumCatalog,
                    style: AppTypography.labelSm(
                      isArabic: l10n.isArabic,
                    ).copyWith(color: AppColors.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.spaceXs),

            // 6. SUBJECT CARDS LIST
            if (subjects.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.spaceXl),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: AppSpacing.spaceSm),
                      Text(
                        l10n.noCoursesFound,
                        style: AppTypography.bodyMd(
                          isArabic: l10n.isArabic,
                        ).copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: AppSpacing.spaceXs,
                ),
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.spaceMd),
                    child: _buildSubjectCard(context, subject, l10n),
                  );
                },
              ),

            const SizedBox(height: AppSpacing.space3xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectCard(
    BuildContext context,
    Subject subject,
    AppLocalizations l10n,
  ) {
    return ThemedCard(
      onTap: () {
        Navigator.of(
          context,
        ).pushNamed('/course-details', arguments: subject.id);
      },
      padding: const EdgeInsets.all(AppSpacing.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top metadata row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Subject Code badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.crimson.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        border: Border.all(
                          color: AppColors.crimson.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        subject.code,
                        style: AppTypography.labelSm().copyWith(
                          color: AppColors.crimson,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    if (subject.term != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          border: Border.all(color: AppColors.subtleHairline),
                        ),
                        child: Text(
                          subject.term!,
                          style: AppTypography.labelSm(isArabic: l10n.isArabic)
                              .copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Hours count
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${subject.hoursCount} ${l10n.isArabic ? "ساعة" : "Hrs"}',
                    style: AppTypography.labelSm().copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceSm),

          // Subject Name
          Text(
            subject.localizedName(l10n.isArabic),
            style: AppTypography.headlineSm(
              isArabic: l10n.isArabic,
            ).copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3),
          ),
          const SizedBox(height: 4),

          // Instructor
          Row(
            children: [
              const Icon(
                Icons.person_pin_circle_outlined,
                size: 14,
                color: AppColors.crimson,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  subject.localizedInstructor(l10n.isArabic),
                  style: AppTypography.bodySm(isArabic: l10n.isArabic).copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            subject.localizedDescription(l10n.isArabic),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySm(
              isArabic: l10n.isArabic,
            ).copyWith(color: AppColors.textMuted, height: 1.35, fontSize: 11),
          ),
          const SizedBox(height: AppSpacing.spaceMd),

          // 4 Subject Content Sections Breakdown Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.subtleHairline),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _buildContentPill(
                  icon: Icons.school_outlined,
                  count: subject.classes.length,
                  label: l10n.tabClasses,
                ),
                _buildContentPill(
                  icon: Icons.play_circle_outline,
                  count: subject.videos.length,
                  label: l10n.tabVideos,
                ),
                _buildContentPill(
                  icon: Icons.menu_book_outlined,
                  count: subject.books.length,
                  label: l10n.tabBooks,
                ),
                _buildContentPill(
                  icon: Icons.description_outlined,
                  count: subject.notes.length,
                  label: l10n.tabMaterials,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.spaceSm),

          // Progress or Action Row
          if (subject.isEnrolled) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      height: 4,
                      color: AppColors.subtleHairline,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (subject.progress / 100).clamp(0.0, 1.0),
                        child: Container(color: AppColors.crimson),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.spaceSm),
                Text(
                  '${subject.progress}%',
                  style: AppTypography.labelSm().copyWith(
                    color: AppColors.crimson,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star,
                      size: 13,
                      color: AppColors.starRating,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      subject.rating.toString(),
                      style: AppTypography.labelSm().copyWith(
                        color: AppColors.starRating,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '(${subject.studentsCount} ${l10n.isArabic ? "دارس" : "Scholars"})',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSm().copyWith(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    subject.isEnrolled
                        ? (l10n.isArabic ? 'متابعة المادة' : 'Continue')
                        : (l10n.isArabic ? 'استعراض المحتوى' : 'View Subject'),
                    style: AppTypography.labelSm(isArabic: l10n.isArabic)
                        .copyWith(
                          color: AppColors.crimson,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward,
                    size: 13,
                    color: AppColors.crimson,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentPill({
    required IconData icon,
    required int count,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.crimson),
        const SizedBox(width: 4),
        Text(
          '$count $label',
          style: AppTypography.labelSm().copyWith(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
