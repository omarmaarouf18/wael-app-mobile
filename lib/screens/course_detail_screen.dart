import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/error_messages.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/academy_catalog_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/themed_error_banner.dart';
import '../widgets/themed_loading_indicator.dart';
import 'course_detail/course_detail_body.dart';

/// Subject detail, read from `GET /academy/subjects/{id}`; opening a locked
/// subject also creates its access request (`openSubject`). Loading, error
/// (persistent banner with Retry; also shown for an unknown or unpublished
/// subject) and ready are separate states. The content itself lives in
/// `course_detail/`.
class CourseDetailScreen extends StatefulWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

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

    final Widget body;
    if (state.detail != null && state.status != LoadStatus.error) {
      // Ready, or refreshing: keep showing what we have.
      body = CourseDetailBody(detail: state.detail!);
    } else if (state.status == LoadStatus.error) {
      body = Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.marginMobile),
          child: ThemedErrorBanner(
            message: ErrorMessages.forCatalog(
              state.error!,
              isArabic: l10n.isArabic,
            ),
            onRetry: () => catalog.openSubject(widget.courseId, force: true),
          ),
        ),
      );
    } else {
      // Idle (first frame) and loading look the same.
      body = const ThemedLoadingIndicator();
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
