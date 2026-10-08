import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/error_messages.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/academy_catalog.dart';
import '../providers/academy_catalog_provider.dart';
import '../providers/app_config_provider.dart';
import '../providers/home_provider.dart';
import '../widgets/accent_title.dart';
import '../widgets/app_shell.dart';
import '../widgets/catalog_level_header.dart';
import '../widgets/catalog_subject_card.dart';
import '../widgets/search_field.dart';
import '../widgets/selectable_chip.dart';
import '../widgets/themed_empty_state.dart';
import '../widgets/themed_error_banner.dart';
import '../widgets/themed_panel.dart';
import '../widgets/themed_skeleton.dart';

/// Icon for a study type key; unknown keys get the generic school icon.
IconData studyTypeIcon(String key) => switch (key) {
  'diploma' => Icons.workspace_premium_outlined,
  'vocational' => Icons.gavel_outlined,
  _ => Icons.school_outlined,
};

/// Courses tab: study type and level pickers over the published subjects of
/// the selected level, read from the academy service. Loading, error (with
/// retry) and empty are separate states.
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AcademyCatalogProvider>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = Provider.of<AcademyCatalogProvider>(context);
    final instructor = Provider.of<HomeProvider>(
      context,
    ).director.localizedName(l10n.isArabic);
    // Owner amendment 2026-10-08 (F-UX6): card prices render only when
    // the public app-config flag allows it (fail closed when
    // offline/empty).
    final showPrices = Provider.of<AppConfigProvider>(context).showPrices;

    return AppShell(
      showHeader: false,
      body: RefreshIndicator(
        color: AppColors.crimson,
        backgroundColor: AppColors.surfaceElevated,
        onRefresh: catalog.reload,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.marginMobile,
                  end: AppSpacing.marginMobile,
                  top: AppSpacing.spaceMd,
                  bottom: AppSpacing.spaceSm,
                ),
                child: SearchField(
                  controller: _searchController,
                  hint: l10n.searchCoursesHint,
                  onChanged: catalog.setSearchQuery,
                  onClear: () {
                    _searchController.clear();
                    catalog.clearSearch();
                  },
                ),
              ),
              ..._body(context, l10n, catalog, instructor, showPrices),
              const SizedBox(height: AppSpacing.space3xl),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    AppLocalizations l10n,
    AcademyCatalogProvider catalog,
    String instructor,
    bool showPrices,
  ) {
    if (catalog.hasError) {
      return [
        Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.marginMobile),
          child: ThemedErrorBanner(
            message: ErrorMessages.forCatalog(
              catalog.error!,
              isArabic: l10n.isArabic,
            ),
            onRetry: catalog.reload,
          ),
        ),
      ];
    }
    if (!catalog.isReady) {
      // Idle (first frame) and loading show skeleton placeholders.
      return const [
        Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.marginMobile),
          child: ThemedPanel(child: ThemedSkeletonList()),
        ),
      ];
    }
    if (catalog.studyTypes.isEmpty) {
      return [
        ThemedEmptyState(icon: Icons.search_off, message: l10n.noCoursesFound),
      ];
    }

    final isArabic = l10n.isArabic;
    final subjects = catalog.visibleSubjects;
    final level = catalog.selectedLevel;
    final type = catalog.selectedStudyType;
    final levels = catalog.levelsOfSelectedType;
    String typeLabel(AcademyStudyType t) =>
        l10n.studyTypeLabel(t.key, t.title.resolve(isArabic));

    return [
      // Education type selector
      Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.marginMobile,
          vertical: AppSpacing.spaceXs,
        ),
        child: AccentTitle(
          title: l10n.educationType,
          color: AppColors.textMuted,
          barHeight: 12,
        ),
      ),
      const SizedBox(height: 4),
      SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.marginMobile,
          ),
          itemCount: catalog.studyTypes.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final t = catalog.studyTypes[index];
            return SelectableChip(
              variant: ChipVariant.outlined,
              icon: studyTypeIcon(t.key),
              label: typeLabel(t),
              selected: t.key == catalog.selectedStudyTypeKey,
              onTap: () => catalog.selectStudyType(t.key),
            );
          },
        ),
      ),
      const SizedBox(height: AppSpacing.spaceSm),

      // A study type with no levels (no diploma yet) is an honest empty state.
      if (levels.isEmpty)
        ThemedEmptyState(
          icon: studyTypeIcon(type?.key ?? ''),
          message: type?.key == 'diploma'
              ? l10n.noDiplomasYet
              : l10n.noLevelsYet,
        )
      else ...[
        // Academic level selector
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.marginMobile,
            vertical: AppSpacing.spaceXs,
          ),
          child: AccentTitle(
            title: l10n.academicYearLevel,
            color: AppColors.textMuted,
            barHeight: 12,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          // Fits the 48dp chip tap targets.
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.marginMobile,
            ),
            itemCount: levels.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final l = levels[index];
              return SelectableChip(
                label: l.title.resolve(isArabic),
                selected: l.key == catalog.selectedLevelKey,
                onTap: () => catalog.selectLevel(l.key),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.spaceSm),

        // Level summary
        if (level != null && type != null)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.marginMobile,
              vertical: AppSpacing.spaceSm,
            ),
            child: CatalogLevelHeader(
              title: level.title.resolve(isArabic),
              subtitle: typeLabel(type),
              countLabel: l10n.subjectsCount(subjects.length),
            ),
          ),

        // Subjects header (both texts shrink instead of overflowing)
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.marginMobile,
            vertical: AppSpacing.spaceXs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  AppTypography.uppercaseLabel(l10n.subjectEntity),
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSm(isArabic: isArabic).copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: isArabic ? 0 : 1.2,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.spaceSm),
              Flexible(
                child: Text(
                  l10n.curriculumCatalog,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSm(
                    isArabic: isArabic,
                  ).copyWith(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.spaceXs),

        // Subject cards
        if (subjects.isEmpty)
          // Nothing published in this level yet, versus a search with no match.
          ThemedEmptyState(
            icon: Icons.search_off,
            message: level != null && catalog.subjectsOf(level.key).isEmpty
                ? l10n.noSubjectsYet
                : l10n.noCoursesFound,
          )
        else
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.marginMobile,
              vertical: AppSpacing.spaceXs,
            ),
            child: Column(
              children: [
                for (final subject in subjects)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: AppSpacing.spaceMd,
                    ),
                    child: CatalogSubjectCard(
                      subject: subject,
                      instructorName: instructor,
                      showPrice: showPrices,
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed('/course-details', arguments: subject.id),
                    ),
                  ),
              ],
            ),
          ),
      ],
    ];
  }
}
