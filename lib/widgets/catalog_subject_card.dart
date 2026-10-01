import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/academy_catalog.dart';
import 'app_badge.dart';
import 'themed_card.dart';
import 'themed_panel.dart';

/// Card for one subject in the courses list: term, title, the academy
/// director's name, a two-line description, content counts (videos, books,
/// notes) and a "View subject" / "Continue" link. Everything shown comes from
/// the academy service except [instructorName], which is the single academy
/// director (the platform has one teacher).
class CatalogSubjectCard extends StatelessWidget {
  const CatalogSubjectCard({
    super.key,
    required this.subject,
    required this.instructorName,
    required this.onTap,
  });

  final AcademySubject subject;
  final String instructorName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    final description = subject.description.resolve(isArabic);

    return ThemedCard(
      onTap: onTap,
      padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subject.hasTerm) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [AppBadge(label: l10n.termLabel(subject.term))],
            ),
            const SizedBox(height: AppSpacing.spaceSm),
          ],
          Text(
            subject.title.resolve(isArabic),
            style: AppTypography.headlineSm(
              isArabic: isArabic,
            ).copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3),
          ),
          const SizedBox(height: 4),
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
                  instructorName,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm(isArabic: isArabic).copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyXs(isArabic: isArabic),
            ),
          ],
          const SizedBox(height: AppSpacing.spaceMd),
          ThemedPanel(
            tone: PanelTone.raised,
            borderRadius: AppRadius.radiusMd,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _CountPill(
                  icon: Icons.play_circle_outline,
                  count: subject.counts.videos,
                  label: l10n.tabVideos,
                ),
                _CountPill(
                  icon: Icons.menu_book_outlined,
                  count: subject.counts.books,
                  label: l10n.tabBooks,
                ),
                _CountPill(
                  icon: Icons.description_outlined,
                  count: subject.counts.notes,
                  label: l10n.tabMaterials,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.spaceSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  subject.owned ? l10n.continueSubject : l10n.viewSubject,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSm(isArabic: isArabic).copyWith(
                    color: AppColors.crimson,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Mirrors automatically in RTL.
              const Icon(
                Icons.arrow_forward,
                size: 13,
                color: AppColors.crimson,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.icon,
    required this.count,
    required this.label,
  });

  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.crimson),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '$count $label',
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSm(isArabic: isArabic).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: isArabic ? 0 : null,
            ),
          ),
        ),
      ],
    );
  }
}
