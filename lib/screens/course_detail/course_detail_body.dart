import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/academy_catalog.dart';
import '../../models/course.dart';
import '../../models/ebook.dart';
import '../../providers/ebook_provider.dart';
import '../../providers/home_provider.dart';
import '../../widgets/director_strip.dart';
import '../../widgets/owned_subject_tile.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/subject_hero_banner.dart';
import '../../widgets/themed_card.dart';
import '../../widgets/themed_panel.dart';
import 'subject_content_section.dart';

/// The ready state of the subject screen: hero, title, director, description,
/// access (owned banner or enrol button), "add to notes" and the content.
class CourseDetailBody extends StatelessWidget {
  const CourseDetailBody({super.key, required this.detail});

  final AcademySubjectDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    final director = Provider.of<HomeProvider>(
      context,
      listen: false,
    ).instructor;
    final description = detail.description.resolve(isArabic);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SubjectHeroBanner(
            imageAsset: AppConstants.imgCatalogComposure,
            fallbackAsset: AppConstants.imgCharacterArt,
            tag: detail.hasTerm ? l10n.termLabel(detail.term) : null,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.marginMobile,
              vertical: AppSpacing.spaceMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 2,
                  color: AppColors.crimson,
                  margin: const EdgeInsetsDirectional.only(
                    bottom: AppSpacing.spaceSm,
                  ),
                ),
                Semantics(
                  header: true,
                  child: Text(
                    detail.title.resolve(isArabic),
                    style: AppTypography.headlineMd(
                      isArabic: isArabic,
                    ).copyWith(fontWeight: FontWeight.w800, height: 1.2),
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceMd),
                DirectorStrip(
                  name: director.localizedName(isArabic),
                  tagline: l10n.directorTagline,
                  imageAsset: AppConstants.imgCharacterArt,
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.spaceMd),
                  Text(
                    description,
                    style: AppTypography.bodyMd(
                      isArabic: isArabic,
                    ).copyWith(height: 1.5),
                  ),
                ],
                const SizedBox(height: AppSpacing.spaceLg),
                _Access(detail: detail),
                const SizedBox(height: AppSpacing.spaceSm),
                _AddToNotes(detail: detail),
                const SizedBox(height: AppSpacing.spaceXl),
                SubjectContentSection(detail: detail),
                const SizedBox(height: AppSpacing.space2xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Access extends StatelessWidget {
  const _Access({required this.detail});

  final AcademySubjectDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;

    if (detail.owned) {
      final expiry = detail.accessExpiresAt;
      return ThemedPanel(
        tone: PanelTone.raised,
        borderRadius: AppRadius.radiusLg,
        padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
        child: Row(
          children: [
            const Icon(
              Icons.verified,
              size: 18,
              color: AppColors.statusApproved,
            ),
            const SizedBox(width: AppSpacing.spaceSm),
            Expanded(
              child: Text(
                l10n.accessActive,
                style: AppTypography.bodyMd(isArabic: isArabic).copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (expiry != null)
              Flexible(
                child: Text(
                  l10n.accessUntil(OwnedSubjectTile.formatDate(expiry)),
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyXs(isArabic: isArabic),
                ),
              ),
          ],
        ),
      );
    }

    final price = detail.price;
    final label = price == null
        ? l10n.enrollNow
        : '${l10n.enrollNow} ($price ${detail.currency ?? 'EGP'})';
    return PrimaryButton(
      text: label,
      leadingIcon: const Icon(
        Icons.lock_open,
        size: 18,
        color: AppColors.textPrimary,
      ),
      onPressed: () {
        final director = Provider.of<HomeProvider>(
          context,
          listen: false,
        ).instructor;
        Navigator.of(context).pushNamed(
          '/payment',
          arguments: Course.fromAcademy(
            detail,
            instructor: director.name,
            instructorAr: director.nameAr ?? director.name,
          ),
        );
      },
    );
  }
}

class _AddToNotes extends StatelessWidget {
  const _AddToNotes({required this.detail});

  final AcademySubjectDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ThemedCard(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
      onTap: () {
        final title = detail.title.resolve(false);
        Provider.of<EBookProvider>(context, listen: false).addNote(
          StudyNote(
            id: 'note-${DateTime.now().millisecondsSinceEpoch}',
            title: 'Observations on $title',
            course: title,
            date: 'Just now',
            tags: [if (detail.hasTerm) '#${detail.term}', '#Dossier'],
            content: 'Key observations recorded for this curriculum.',
          ),
        );
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.noteCreated)));
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.note_add_outlined,
            size: 16,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              l10n.addToNotes,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSm(
                isArabic: l10n.isArabic,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
