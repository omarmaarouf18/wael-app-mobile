import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/error_messages.dart';
import '../core/external_links.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/academy_catalog_provider.dart';
import '../providers/app_config_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/themed_error_banner.dart';
import '../widgets/themed_panel.dart';
import '../widgets/themed_skeleton.dart';
import 'course_detail/course_detail_body.dart';

/// Subject detail, read from `GET /academy/subjects/{id}`; opening a locked
/// subject also creates its access request (`openSubject`). Loading, error
/// (persistent banner with Retry; also shown for an unknown or unpublished
/// subject) and ready are separate states. The content itself lives in
/// `course_detail/`.
class CourseDetailScreen extends StatefulWidget {
  final String courseId;

  /// Opens the support WhatsApp chat. Injected in widget tests.
  final LaunchUrl launchUrl;

  const CourseDetailScreen({
    super.key,
    required this.courseId,
    this.launchUrl = defaultLaunchUrl,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AcademyCatalogProvider>().openSubject(widget.courseId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = Provider.of<AcademyCatalogProvider>(context);
    final state = catalog.detailOf(widget.courseId);
    // Owner amendment 2026-10-08 (F-UX6): prices render only when the
    // public app-config flag allows it (fail closed when offline/empty).
    final showPrices = Provider.of<AppConfigProvider>(context).showPrices;

    Future<void> onRefresh() =>
        catalog.openSubject(widget.courseId, force: true);

    final Widget body;
    if (state.detail != null && state.status != LoadStatus.error) {
      // Ready, or refreshing: keep showing what we have. The body scrolls
      // itself with always-scrollable physics so pull-to-refresh works.
      body = RefreshIndicator(
        color: AppColors.crimson,
        backgroundColor: AppColors.surfaceElevated,
        onRefresh: onRefresh,
        child: CourseDetailBody(
          detail: state.detail!,
          launchUrl: widget.launchUrl,
          showPrice: showPrices,
        ),
      );
    } else if (state.status == LoadStatus.error) {
      body = RefreshIndicator(
        color: AppColors.crimson,
        backgroundColor: AppColors.surfaceElevated,
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppSpacing.marginMobile),
              child: ThemedErrorBanner(
                message: ErrorMessages.forCatalog(
                  state.error!,
                  isArabic: l10n.isArabic,
                ),
                onRetry: () =>
                    catalog.openSubject(widget.courseId, force: true),
              ),
            ),
          ),
        ),
      );
    } else {
      // Idle (first frame) and loading show skeleton placeholders.
      body = RefreshIndicator(
        color: AppColors.crimson,
        backgroundColor: AppColors.surfaceElevated,
        onRefresh: onRefresh,
        child: const SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.all(AppSpacing.marginMobile),
            child: ThemedPanel(child: ThemedSkeletonList()),
          ),
        ),
      );
    }

    return AppShell(
      showBack: true,
      titleWidget: Text(
        AppTypography.uppercaseLabel(l10n.courseDossier),
        style: AppTypography.labelSm(isArabic: l10n.isArabic).copyWith(
          letterSpacing: l10n.isArabic ? 0 : 1.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: body,
    );
  }
}
