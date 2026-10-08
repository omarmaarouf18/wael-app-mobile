import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/external_links.dart' show LaunchUrl, defaultLaunchUrl;
import '../core/legal_links.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_config_provider.dart';
import 'primary_button.dart';
import 'secondary_button.dart';
import 'themed_section_header.dart';

/// The short terms/privacy summary shown at signup (owner decision
/// 2026-10-08): tappable consent names open this sheet instead of the bare
/// checkbox label. Bullets match the website legal pages v2.0.
///
/// Returns true when the student taps the agree button (the caller ticks
/// the checkbox); any other dismissal returns false and leaves the
/// checkbox as it was. The two full-page buttons open the website pages
/// externally (`https` only).
Future<bool> showLegalSummarySheet(
  BuildContext context, {
  LaunchUrl? launchUrl,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      final isArabic = l10n.isArabic;
      final config = Provider.of<AppConfigProvider>(ctx, listen: false);
      final termsUrl = withUiLanguage(
        legalTermsUrl(config.termsUrl),
        isArabic: isArabic,
      );
      final privacyUrl = withUiLanguage(
        legalPrivacyUrl(config.privacyUrl),
        isArabic: isArabic,
      );
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(AppSpacing.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Center(
                  child: SizedBox(
                    width: 36,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.subtleHairline,
                        borderRadius: AppRadius.radiusPill,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceMd),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.legalSheetTitle,
                    style: AppTypography.headlineSm(
                      isArabic: isArabic,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceMd),
                ThemedSectionHeader(
                  title: l10n.termsSummaryTitle,
                  uppercase: false,
                ),
                for (final bullet in l10n.termsSummaryBullets)
                  _Bullet(text: bullet),
                const SizedBox(height: AppSpacing.spaceMd),
                ThemedSectionHeader(
                  title: l10n.privacySummaryTitle,
                  uppercase: false,
                ),
                for (final bullet in l10n.privacySummaryBullets)
                  _Bullet(text: bullet),
                const SizedBox(height: AppSpacing.spaceLg),
                SecondaryButton(
                  text: l10n.readTermsFull,
                  height: 44,
                  trailingIcon: const Icon(
                    Icons.open_in_new_outlined,
                    size: 16,
                    color: AppColors.textPrimary,
                  ),
                  onPressed: () => openLegalPage(
                    termsUrl,
                    launch: launchUrl ?? defaultLaunchUrl,
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceSm),
                SecondaryButton(
                  text: l10n.readPrivacyFull,
                  height: 44,
                  trailingIcon: const Icon(
                    Icons.open_in_new_outlined,
                    size: 16,
                    color: AppColors.textPrimary,
                  ),
                  onPressed: () => openLegalPage(
                    privacyUrl,
                    launch: launchUrl ?? defaultLaunchUrl,
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceMd),
                PrimaryButton(
                  text: l10n.legalAgree,
                  height: 48,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          ),
        ),
      );
    },
  ).then((agreed) => agreed ?? false);
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.spaceXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: AppTypography.bodyMd(
              isArabic: isArabic,
            ).copyWith(color: AppColors.danger),
          ),
          const SizedBox(width: AppSpacing.spaceSm),
          Expanded(
            child: Text(text, style: AppTypography.bodyMd(isArabic: isArabic)),
          ),
        ],
      ),
    );
  }
}
