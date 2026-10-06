import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/external_links.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_config_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/icon_tile.dart';
import '../widgets/primary_button.dart';
import '../widgets/themed_card.dart';

/// Full-screen blocking gate shown at launch when the installed version is
/// strictly below `min_version` from public app config (SPEC F-UX2 Part B).
class UpdateGateScreen extends StatelessWidget {
  const UpdateGateScreen({super.key, LaunchUrl? launch})
    : launch = launch ?? defaultLaunchUrl;

  final LaunchUrl launch;

  Future<void> _openUpdateUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
    await launch(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appConfig = Provider.of<AppConfigProvider?>(context);
    final updateUrl = appConfig?.config.updateUrl.trim() ?? '';
    final hasUpdateUrl =
        updateUrl.isNotEmpty && (Uri.tryParse(updateUrl)?.scheme == 'https');

    return PopScope(
      canPop: false,
      child: AppShell(
        showHeader: false,
        safeArea: true,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spaceXl,
              vertical: AppSpacing.space2xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const IconTile(
                  icon: Icons.system_update_rounded,
                  iconColor: AppColors.crimson,
                  background: AppColors.crimsonTinted,
                  size: 72,
                  iconSize: 36,
                  borderRadius: AppRadius.radiusLg,
                ),
                const SizedBox(height: AppSpacing.spaceXl),
                Text(
                  l10n.updateRequiredTitle,
                  style: AppTypography.headlineMd(isArabic: l10n.isArabic),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.spaceMd),
                Text(
                  l10n.updateRequiredMessage,
                  style: AppTypography.bodyMd(
                    isArabic: l10n.isArabic,
                  ).copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.space2xl),
                if (hasUpdateUrl)
                  PrimaryButton(
                    text: l10n.updateNow,
                    leadingIcon: const Icon(
                      Icons.download_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    onPressed: () => _openUpdateUrl(updateUrl),
                  )
                else
                  ThemedCard(
                    padding: const EdgeInsets.all(AppSpacing.spaceLg),
                    child: Text(
                      l10n.updateContactSupport,
                      style: AppTypography.bodySm(
                        isArabic: l10n.isArabic,
                      ).copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
