import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/error_messages.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/academy_catalog_provider.dart';
import '../providers/home_provider.dart';
import '../widgets/accent_title.dart';
import '../widgets/app_shell.dart';
import '../widgets/home_hero_banner.dart';
import '../widgets/instructor_dossier_card.dart';
import '../widgets/owned_subject_tile.dart';
import '../widgets/secondary_button.dart';
import '../widgets/themed_empty_state.dart';
import '../widgets/themed_error_banner.dart';
import '../widgets/themed_panel.dart';
import '../widgets/themed_skeleton.dart';

/// Home tab: hero, the academy director (only when the owner has filled in
/// `lib/content/director_profile.dart`), and the subjects the student owns.
///
/// "My courses" comes from the academy service (`owned` flags); it has
/// loading, error (with retry) and empty states. Pull to refresh reloads the
/// catalog.
class HomeScreen extends StatefulWidget {
  final VoidCallback? onExploreCourses;

  const HomeScreen({super.key, this.onExploreCourses});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AcademyCatalogProvider>().ensureLoaded();
    });
  }

  void _explore() {
    final callback = widget.onExploreCourses;
    if (callback != null) {
      callback();
    } else {
      Navigator.of(context).pushNamed('/courses');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final home = Provider.of<HomeProvider>(context);
    final catalog = Provider.of<AcademyCatalogProvider>(context);

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
              HomeHeroBanner(onExplore: _explore),

              // Academy director: hidden while the profile has no content.
              if (home.director.hasContent)
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.marginMobile,
                    vertical: AppSpacing.spaceSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AccentTitle(title: l10n.instructorSectionTitle),
                      const SizedBox(height: AppSpacing.spaceSm),
                      InstructorDossierCard(
                        profile: home.director,
                        bioExpanded: home.isBioExpanded,
                        onToggleBio: home.toggleBioExpansion,
                      ),
                    ],
                  ),
                ),

              // My courses (owned subjects)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: AppSpacing.spaceSm,
                ),
                child: _MyCourses(catalog: catalog, onExplore: _explore),
              ),
              const SizedBox(height: AppSpacing.spaceXl),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyCourses extends StatelessWidget {
  const _MyCourses({required this.catalog, required this.onExplore});

  final AcademyCatalogProvider catalog;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;

    final Widget content;
    if (catalog.hasError) {
      content = ThemedErrorBanner(
        message: ErrorMessages.forCatalog(catalog.error!, isArabic: isArabic),
        onRetry: catalog.reload,
      );
    } else if (!catalog.isReady) {
      // Idle (first frame) and loading show skeleton placeholders.
      content = const ThemedPanel(child: ThemedSkeletonList());
    } else {
      final owned = catalog.ownedSubjects;
      content = owned.isEmpty
          ? ThemedPanel(
              child: ThemedEmptyState(
                icon: Icons.school_outlined,
                message: l10n.noOwnedCourses,
                action: SecondaryButton(
                  text: l10n.exploreCourses,
                  onPressed: onExplore,
                ),
              ),
            )
          : Column(
              children: [
                for (final subject in owned) ...[
                  OwnedSubjectTile(
                    subject: subject,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed('/course-details', arguments: subject.id),
                  ),
                  const SizedBox(height: AppSpacing.spaceSm),
                ],
              ],
            );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.myCourses,
              style: AppTypography.labelSm(isArabic: isArabic).copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: isArabic ? 0 : 1.2,
              ),
            ),
            InkWell(
              onTap: onExplore,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.viewAll,
                    style: AppTypography.labelSm(
                      isArabic: isArabic,
                    ).copyWith(color: AppColors.textMuted),
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
        content,
      ],
    );
  }
}
