import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/error_messages.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/academy_catalog.dart';
import '../../providers/academy_catalog_provider.dart';
import '../../providers/home_provider.dart';
import '../../widgets/director_strip.dart';
import '../../widgets/owned_subject_tile.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/subject_hero_banner.dart';
import '../../widgets/themed_error_banner.dart';
import '../../widgets/themed_panel.dart';
import 'subject_content_section.dart';

/// The ready state of the subject screen: hero, title, director, description,
/// access (owned, request pending, sending or failed), "add to notes" and the
/// content.
class CourseDetailBody extends StatelessWidget {
  const CourseDetailBody({super.key, required this.detail});

  final AcademySubjectDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    final director = Provider.of<HomeProvider>(context, listen: false).director;
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
                if (director.hasContent) ...[
                  const SizedBox(height: AppSpacing.spaceMd),
                  DirectorStrip(
                    name: director.localizedName(isArabic),
                    tagline: director.localizedTagline(isArabic),
                    imageAsset: director.portraitAsset,
                  ),
                ],
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

/// Access state of the subject. Opening a locked subject creates the access
/// request by itself (SPEC decision 9, see `AcademyCatalogProvider.openSubject`),
/// so there is no button to ask for access: the student sees the request being
/// sent, then pending, or the reason it could not be sent.
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

    final catalog = context.watch<AcademyCatalogProvider>();
    final access = catalog.accessOf(detail.id);

    if (detail.hasPendingRequest || access.status == AccessRequestStatus.sent) {
      return _PendingRequest(supportUrl: access.supportUrl);
    }
    if (access.status == AccessRequestStatus.failed) {
      return ThemedErrorBanner(
        message: ErrorMessages.forAccessRequest(
          access.error!,
          isArabic: isArabic,
        ),
        onRetry: access.canRetry
            ? () => catalog.requestAccess(detail.id)
            : null,
      );
    }
    // Idle (the first frame before the request starts) and sending.
    return ThemedPanel(
      tone: PanelTone.raised,
      borderRadius: AppRadius.radiusLg,
      padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.crimson),
              ),
            ),
            const SizedBox(width: AppSpacing.spaceMd),
            Expanded(
              child: Text(
                l10n.sendingAccessRequest,
                style: AppTypography.bodyMd(
                  isArabic: isArabic,
                ).copyWith(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A request is pending: nothing to press, the admin decides. [supportUrl] is
/// the WhatsApp link from this session's request response; the detail does not
/// carry it, so after a restart the panel shows the message alone.
class _PendingRequest extends StatelessWidget {
  const _PendingRequest({this.supportUrl});

  final String? supportUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    final url = supportUrl;

    return ThemedPanel(
      tone: PanelTone.raised,
      borderRadius: AppRadius.radiusLg,
      padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule,
                size: 18,
                color: AppColors.statusPending,
              ),
              const SizedBox(width: AppSpacing.spaceSm),
              Expanded(
                child: Text(
                  l10n.requestPending,
                  style: AppTypography.bodyMd(isArabic: isArabic).copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceXs),
          Text(
            l10n.contactSupportToActivate,
            style: AppTypography.bodySm(isArabic: isArabic),
          ),
          if (url != null) ...[
            const SizedBox(height: AppSpacing.spaceMd),
            SecondaryButton(
              text: l10n.copySupportLink,
              height: 44,
              leadingIcon: const Icon(
                Icons.copy,
                size: 16,
                color: AppColors.textPrimary,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final message = l10n.supportLinkCopied;
                await Clipboard.setData(ClipboardData(text: url));
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(message)));
              },
            ),
          ],
        ],
      ),
    );
  }
}
