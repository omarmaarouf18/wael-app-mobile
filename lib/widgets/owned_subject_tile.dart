import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/academy_catalog.dart';
import 'icon_tile.dart';
import 'themed_card.dart';

/// Home-screen row for a subject the student owns: icon tile, title, content
/// counts and either the access end date or "Ready to start".
class OwnedSubjectTile extends StatelessWidget {
  const OwnedSubjectTile({
    super.key,
    required this.subject,
    required this.onTap,
  });

  final AcademySubject subject;
  final VoidCallback onTap;

  static String formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    final counts = subject.counts;
    final expiry = subject.accessExpiresAt;

    return ThemedCard(
      padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
      onTap: onTap,
      child: Row(
        children: [
          const IconTile(
            icon: Icons.school_outlined,
            iconColor: AppColors.crimson,
            size: 48,
            iconSize: 22,
            borderRadius: AppRadius.radiusLg,
          ),
          const SizedBox(width: AppSpacing.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.title.resolve(isArabic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMd(
                    isArabic: isArabic,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${counts.videos} ${l10n.tabVideos} • ${counts.books} ${l10n.tabBooks}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyXs(isArabic: isArabic),
                ),
                const SizedBox(height: 4),
                Text(
                  expiry == null
                      ? l10n.readyToStart
                      : l10n.accessUntil(formatDate(expiry)),
                  style: AppTypography.labelSm(isArabic: isArabic).copyWith(
                    color: AppColors.crimson,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
