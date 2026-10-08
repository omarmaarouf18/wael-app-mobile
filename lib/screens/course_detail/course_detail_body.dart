import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import '../../core/constants.dart';
import '../../core/error_messages.dart';
import '../../core/external_links.dart';
import '../../core/price_format.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/academy_catalog.dart';
import '../../providers/academy_catalog_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_provider.dart';
import '../../widgets/director_strip.dart';
import '../../widgets/owned_subject_tile.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/subject_hero_banner.dart';
import '../../widgets/subject_price.dart';
import '../../widgets/themed_error_banner.dart';
import '../../widgets/themed_panel.dart';
import 'subject_content_section.dart';

/// The ready state of the subject screen: hero, title, director, description,
/// access (owned, request pending, sending or failed), "add to notes" and the
/// content.
class CourseDetailBody extends StatelessWidget {
  const CourseDetailBody({
    super.key,
    required this.detail,
    this.launchUrl = defaultLaunchUrl,
    this.showPrice = false,
  });

  final AcademySubjectDetail detail;

  /// Opens the support WhatsApp chat. Injected in widget tests.
  final LaunchUrl launchUrl;

  /// Owner amendment 2026-10-08 (F-UX6): the price renders only when the
  /// public app-config flag `show_prices` is true (the screen passes it
  /// down). Defaults to hidden (fail closed).
  final bool showPrice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    final director = Provider.of<HomeProvider>(context, listen: false).director;
    final description = detail.description.resolve(isArabic);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SubjectHeroBanner(
            imageAsset: AppConstants.imgSubjectBanner,
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
                // The server-sent price, locked subjects only and only when
                // the app-config flag allows it: anything else renders
                // nothing (and no gap). It stays in the header, never in
                // the support panel below.
                if (shouldShowSubjectPrice(
                  owned: detail.owned,
                  price: detail.price,
                  showPrices: showPrice,
                )) ...[
                  const SizedBox(height: AppSpacing.spaceMd),
                  SubjectPriceTag(
                    amount: detail.price!,
                    currency: detail.currency,
                    isArabic: isArabic,
                  ),
                ],
                const SizedBox(height: AppSpacing.spaceLg),
                _Access(detail: detail, launchUrl: launchUrl),
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
  const _Access({required this.detail, required this.launchUrl});

  final AcademySubjectDetail detail;
  final LaunchUrl launchUrl;

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
      return _PendingRequest(
        supportUrl: access.supportUrl,
        subjectTitle: detail.title.resolve(isArabic),
        launchUrl: launchUrl,
      );
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

/// A request is pending: the admin decides. The primary action opens the
/// support WhatsApp chat ([supportUrl] is the link from this session's
/// request response; the detail does not carry it, so after a restart the
/// panel shows the copy action only when the provider still holds the URL).
/// When opening fails, the copy-to-clipboard behaviour is the fallback.
class _PendingRequest extends StatelessWidget {
  const _PendingRequest({
    this.supportUrl,
    required this.subjectTitle,
    this.launchUrl = defaultLaunchUrl,
  });

  final String? supportUrl;
  final String subjectTitle;
  final LaunchUrl launchUrl;

  Future<void> _copyLink(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocalizations.of(context).supportLinkCopied;
    await Clipboard.setData(ClipboardData(text: url));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    final url = supportUrl;
    final email = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser.email;
    final openUri = whatsappUrl(
      supportUrl: url,
      messageText: l10n.whatsappRequestText(subjectTitle, email),
    );

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
            if (openUri != null)
              PrimaryButton(
                text: l10n.openWhatsApp,
                height: 44,
                leadingIcon: const Icon(
                  Icons.chat_outlined,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
                onPressed: () async {
                  bool opened = false;
                  try {
                    opened = await launchUrl(
                      openUri,
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (_) {
                    opened = false;
                  }
                  if (!opened && context.mounted) {
                    await _copyLink(context, url);
                  }
                },
              ),
            if (openUri != null) const SizedBox(height: AppSpacing.spaceSm),
            SecondaryButton(
              text: l10n.copySupportLink,
              height: 44,
              leadingIcon: const Icon(
                Icons.copy,
                size: 16,
                color: AppColors.textPrimary,
              ),
              onPressed: () => _copyLink(context, url),
            ),
          ],
        ],
      ),
    );
  }
}
