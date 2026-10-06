import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/error_messages.dart';
import '../core/haptics.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/notifications_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/icon_tile.dart';
import '../widgets/status_dot.dart';
import '../widgets/themed_card.dart';
import '../widgets/themed_empty_state.dart';
import '../widgets/themed_error_banner.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notifProvider = Provider.of<NotificationsProvider>(context);
    final items = notifProvider.notifications;

    return AppShell(
      showBack: true,
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const StatusDot(size: 6),
          const SizedBox(width: AppSpacing.spaceSm),
          Flexible(
            child: Text(
              AppTypography.uppercaseLabel(l10n.dispatchesTitle),
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSm().copyWith(
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => notifProvider.markAllAsRead(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            AppTypography.uppercaseLabel(l10n.markAllRead),
            style: AppTypography.actionSm(isArabic: l10n.isArabic),
          ),
        ),
      ],
      body: RefreshIndicator(
        color: AppColors.crimson,
        backgroundColor: AppColors.surfaceElevated,
        onRefresh: notifProvider.loadRemote,
        child: items.isEmpty
            ? (notifProvider.hasError
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.all(
                            AppSpacing.marginMobile,
                          ),
                          child: ThemedErrorBanner(
                            message: ErrorMessages.notificationLoadFailed(
                              l10n.isArabic,
                            ),
                            onRetry: notifProvider.loadRemote,
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      child: ThemedEmptyState(
                        icon: Icons.notifications_off_outlined,
                        message: l10n.noNotifications,
                      ),
                    ))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: AppSpacing.spaceMd,
                ),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.spaceSm),
                itemBuilder: (context, index) {
                  final item = items[index];

                  IconData iconData;
                  Color iconColor;
                  switch (item.type) {
                    case 'payment':
                      iconData = Icons.verified;
                      iconColor = AppColors.statusApproved;
                      break;
                    case 'event':
                      iconData = Icons.event;
                      iconColor = AppColors.danger;
                      break;
                    case 'course':
                      iconData = Icons.auto_stories;
                      iconColor = AppColors.textPrimary;
                      break;
                    default:
                      iconData = Icons.info_outline;
                      iconColor = AppColors.textSecondary;
                  }

                  return ThemedCard(
                    onTap: () {
                      notifProvider.markAsRead(item.id);
                      AppHaptics.light();
                      // A notification that refers to a subject opens that
                      // subject's detail. Without a subject id (the backend
                      // sends none today) only the notifications list opens:
                      // a target pointing back at the list itself stays put.
                      final subjectId = item.subjectId;
                      if (subjectId != null) {
                        Navigator.of(
                          context,
                        ).pushNamed('/course-details', arguments: subjectId);
                      } else if (item.targetRoute != null &&
                          item.targetRoute != '/notifications') {
                        Navigator.of(context).pushNamed(item.targetRoute!);
                      }
                    },
                    backgroundColor: item.isRead
                        ? AppColors.surfaceLayer1
                        : AppColors.surfaceElevated,
                    borderColor: item.isRead
                        ? AppColors.subtleHairline
                        : AppColors.crimson.withValues(alpha: 0.35),
                    padding: const EdgeInsetsDirectional.all(
                      AppSpacing.spaceMd,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Unread pip
                        Padding(
                          padding: const EdgeInsetsDirectional.only(top: 6),
                          child: StatusDot(
                            color: item.isRead
                                ? AppColors.subtleHairline
                                : AppColors.danger,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.spaceMd),

                        // Icon
                        IconTile(icon: iconData, iconColor: iconColor),
                        const SizedBox(width: AppSpacing.spaceMd),

                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.localizedTitle(l10n.isArabic),
                                      style:
                                          AppTypography.bodySm(
                                            isArabic: l10n.isArabic,
                                          ).copyWith(
                                            fontWeight: item.isRead
                                                ? FontWeight.w600
                                                : FontWeight.w700,
                                            color: item.isRead
                                                ? AppColors.textSecondary
                                                : AppColors.textPrimary,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    item.localizedTimestamp(l10n.isArabic),
                                    style: AppTypography.caption(
                                      isArabic: l10n.isArabic,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.localizedBody(l10n.isArabic),
                                style: AppTypography.bodyXs(
                                  isArabic: l10n.isArabic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
