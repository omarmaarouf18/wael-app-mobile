import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/notifications_provider.dart';
import '../widgets/themed_card.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notifProvider = Provider.of<NotificationsProvider>(context);
    final items = notifProvider.notifications;

    return Scaffold(
      backgroundColor: AppColors.voidCanvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.textSecondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.crimson,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n.dispatchesTitle.toUpperCase(),
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
              l10n.markAllRead.toUpperCase(),
              style: AppTypography.labelSm(isArabic: l10n.isArabic).copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.spaceSm),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.notifications_off_outlined,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),
                  Text(
                    l10n.noNotifications,
                    style: AppTypography.bodyMd().copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
                vertical: AppSpacing.spaceMd,
              ),
              physics: const BouncingScrollPhysics(),
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
                    iconColor = AppColors.crimson;
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
                    if (item.targetRoute != null) {
                      Navigator.of(context).pushNamed(item.targetRoute!);
                    }
                  },
                  backgroundColor: item.isRead
                      ? AppColors.surfaceLayer1
                      : AppColors.surfaceElevated,
                  borderColor: item.isRead
                      ? AppColors.subtleHairline
                      : AppColors.crimson.withValues(alpha: 0.35),
                  padding: const EdgeInsets.all(AppSpacing.spaceMd),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Unread pip
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: item.isRead
                              ? AppColors.subtleHairline
                              : AppColors.crimson,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.spaceMd),

                      // Icon
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(iconData, size: 18, color: iconColor),
                      ),
                      const SizedBox(width: AppSpacing.spaceMd),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                              : Colors.white,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  item.localizedTimestamp(l10n.isArabic),
                                  style: const TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.localizedBody(l10n.isArabic),
                              style:
                                  AppTypography.bodySm(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                    height: 1.4,
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
    );
  }
}
