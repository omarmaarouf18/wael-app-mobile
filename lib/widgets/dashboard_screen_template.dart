import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';

class DashboardScreenTemplate extends StatelessWidget {
  final Widget body;
  final String? title;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget>? customActions;
  final bool showHeader;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool isEmpty;
  final String? emptyMessage;
  final Widget? floatingActionButton;

  const DashboardScreenTemplate({
    super.key,
    required this.body,
    this.title,
    this.showBack = false,
    this.onBack,
    this.customActions,
    this.showHeader = true,
    this.isLoading = false,
    this.hasError = false,
    this.errorMessage,
    this.onRetry,
    this.isEmpty = false,
    this.emptyMessage,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.voidCanvas,
      appBar: showHeader
          ? PreferredSize(
              preferredSize: const Size.fromHeight(AppSpacing.headerHeight),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.headerGlass,
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.glassHairline,
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.marginMobile,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (showBack)
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 18,
                            ),
                            color: AppColors.textSecondary,
                            onPressed:
                                onBack ?? () => Navigator.of(context).pop(),
                            splashRadius: 20,
                          )
                        else
                          // Brand Wordmark
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title ?? l10n.appTitle,
                                style: AppTypography.headlineSm().copyWith(
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 1,
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Text(
                                      l10n.appSubtitle,
                                      style: AppTypography.academyEyebrow()
                                          .copyWith(
                                            fontSize: 8,
                                            letterSpacing: 2.5,
                                          ),
                                    ),
                                  ),
                                  Container(
                                    width: 10,
                                    height: 1,
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        // Right Actions
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children:
                              customActions ??
                              [
                                // Notification / Dispatch icon with crimson dot
                                InkWell(
                                  onTap: () {
                                    Navigator.of(
                                      context,
                                    ).pushNamed('/notifications');
                                  },
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLayer1,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.subtleHairline,
                                        width: 1,
                                      ),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        const Icon(
                                          Icons.notifications_outlined,
                                          size: 18,
                                          color: AppColors.textPrimary,
                                        ),
                                        Positioned(
                                          top: 7,
                                          right: 7,
                                          child: Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              color: AppColors.crimson,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.voidCanvas,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.spaceSm),
                                // Profile circle
                                InkWell(
                                  onTap: () {
                                    Navigator.of(
                                      context,
                                    ).pushNamed('/settings');
                                  },
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLayer1,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.subtleHairline,
                                        width: 1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.person_outline,
                                      size: 18,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        top: !showHeader,
        bottom: false,
        child: _buildContent(context, l10n),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.crimson),
        ),
      );
    }

    if (hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.crimson,
              ),
              const SizedBox(height: AppSpacing.spaceMd),
              Text(
                errorMessage ?? l10n.errorLoading,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd().copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.spaceLg),
              if (onRetry != null)
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceElevated,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.subtleHairline),
                  ),
                  child: Text(l10n.retry),
                ),
            ],
          ),
        ),
      );
    }

    if (isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inbox_outlined,
                size: 48,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: AppSpacing.spaceMd),
              Text(
                emptyMessage ?? l10n.noCoursesFound,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd().copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return body;
  }
}
