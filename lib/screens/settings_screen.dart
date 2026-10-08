import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/external_links.dart'
    show LaunchUrl, defaultLaunchUrl, openSupportChat;
import '../core/legal_links.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_config_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/logout_helper.dart';
import '../widgets/app_shell.dart';
import 'settings/profile_section.dart';
import 'settings/delete_account_screen.dart';
import 'settings/devices_screen.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/icon_tile.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/themed_card.dart';
import '../widgets/themed_section_header.dart';

/// Settings tab. Everything here is real: the profile header is the signed-in
/// account (`GET /auth/me`: name, email, phone), the language switch changes
/// the app language (the choice is saved on the device and wins over the
/// device language), the about section opens the server-provided terms and
/// privacy pages, and sign out ends the session after a confirmation.
/// There are no other toggles.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.launchUrl});

  /// Opens external links (terms, privacy). Tests inject a mock.
  final LaunchUrl? launchUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final appConfig = Provider.of<AppConfigProvider>(context);
    final launch = launchUrl ?? defaultLaunchUrl;
    final user = auth.currentUser;
    final name = user.fullName.trim();
    final phone = user.phone.trim();
    // Owner amendment 2026-10-08 (F-UX6): optional tutoring-center info.
    // A missing center (or one with nothing to show) renders nothing.
    final center = appConfig.center;
    final centerInfoVisible = center?.hasContent ?? false;
    final centerMapVisible = center?.mapUrl.isNotEmpty ?? false;

    return AppShell(
      showHeader: false,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.marginMobile,
          vertical: AppSpacing.spaceMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. PROFILE HEADER CARD (the signed-in account)
            ThemedCard(
              padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
              child: Row(
                children: [
                  const ProfileAvatar(showBadge: false),
                  const SizedBox(width: AppSpacing.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Accounts created before the name was collected have
                        // none: show the email instead of an empty title.
                        Text(
                          name.isNotEmpty ? name : user.email,
                          style: AppTypography.headlineSm(
                            isArabic: l10n.isArabic,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (name.isNotEmpty && user.email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            user.email,
                            style: AppTypography.bodyXs(
                              isArabic: l10n.isArabic,
                            ).copyWith(color: AppColors.textTertiary),
                          ),
                        ],
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          // Phone numbers read left to right even in Arabic.
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              phone,
                              style: AppTypography.bodyXs(
                                isArabic: l10n.isArabic,
                              ).copyWith(color: AppColors.textTertiary),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.spaceLg),

            // 2. MY ACCOUNT (name, phone, email, password)
            const ProfileSection(),
            const SizedBox(height: AppSpacing.spaceLg),

            // 3. MY DEVICES
            ThemedSectionHeader(title: l10n.myDevices),
            ThemedCard(
              padding: EdgeInsets.zero,
              child: _buildNavigationTile(
                icon: Icons.devices_outlined,
                title: l10n.myDevices,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DevicesScreen()),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.spaceLg),

            // 4. LANGUAGE
            ThemedSectionHeader(title: l10n.languageAndPreferences),
            ThemedCard(
              padding: EdgeInsets.zero,
              child: _buildNavigationTile(
                icon: Icons.language,
                title: l10n.languageAndSubtitles,
                trailingText: localeProvider.isArabic ? 'العربية' : 'English',
                onTap: () {
                  localeProvider.toggleLocale();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.surfaceElevated,
                      duration: const Duration(seconds: 1),
                      content: Text(
                        l10n.languageSwitched(localeProvider.isArabic),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.spaceXl),

            // 5. HELP (server-provided WhatsApp chat + tutoring center)
            if (appConfig.supportWhatsappUrl.isNotEmpty ||
                centerInfoVisible ||
                centerMapVisible) ...[
              ThemedSectionHeader(title: l10n.helpTitle),
              if (appConfig.supportWhatsappUrl.isNotEmpty)
                ThemedCard(
                  padding: EdgeInsets.zero,
                  child: _buildNavigationTile(
                    icon: Icons.support_agent_outlined,
                    title: l10n.contactWhatsApp,
                    onTap: () async {
                      final ok = await openSupportChat(
                        supportUrl: appConfig.supportWhatsappUrl,
                        messageText: l10n.whatsappHelpText,
                        launch: launch,
                      );
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.surfaceElevated,
                            content: Text(l10n.supportOpenFailed),
                          ),
                        );
                      }
                    },
                  ),
                ),
              // Owner amendment 2026-10-08 (F-UX6): optional center
              // info from app-config. Absent renders nothing. No price
              // or payment wording here, ever.
              if (appConfig.supportWhatsappUrl.isNotEmpty &&
                  (centerInfoVisible || centerMapVisible))
                const SizedBox(height: AppSpacing.spaceMd),
              if (centerInfoVisible)
                ThemedCard(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (center!.name.isNotEmpty)
                        Text(
                          center.name,
                          style: AppTypography.headlineSm(
                            isArabic: l10n.isArabic,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      if (center.address.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.spaceXs),
                        Text(
                          center.address,
                          style: AppTypography.bodyMd(isArabic: l10n.isArabic),
                        ),
                      ],
                      if (center.hoursFor(l10n.isArabic).isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.spaceXs),
                        Text(
                          center.hoursFor(l10n.isArabic),
                          style: AppTypography.bodySm(
                            isArabic: l10n.isArabic,
                          ).copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              if (centerMapVisible) ...[
                const SizedBox(height: AppSpacing.spaceMd),
                ThemedCard(
                  padding: EdgeInsets.zero,
                  child: _buildNavigationTile(
                    icon: Icons.map_outlined,
                    title: l10n.openMap,
                    onTap: () => _openExternal(context, launch, center!.mapUrl),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.spaceXl),
            ],

            // 6. ABOUT (terms + privacy pages with fallbacks, installed version)
            ThemedSectionHeader(title: l10n.aboutApp),
            ThemedCard(
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNavigationTile(
                    icon: Icons.description_outlined,
                    title: l10n.termsTitle,
                    onTap: () => _openExternal(
                      context,
                      launch,
                      withUiLanguage(
                        legalTermsUrl(appConfig.termsUrl),
                        isArabic: l10n.isArabic,
                      ),
                    ),
                  ),
                  _buildNavigationTile(
                    icon: Icons.privacy_tip_outlined,
                    title: l10n.privacyTitle,
                    onTap: () => _openExternal(
                      context,
                      launch,
                      withUiLanguage(
                        legalPrivacyUrl(appConfig.privacyUrl),
                        isArabic: l10n.isArabic,
                      ),
                    ),
                  ),
                  FutureBuilder<String>(
                    future: appConfig.currentVersion(),
                    builder: (context, snapshot) {
                      final version = snapshot.data ?? '';
                      final isUpdateAvailable =
                          version.isNotEmpty &&
                          appConfig.updateState(version) ==
                              UpdateState.available &&
                          appConfig.config.updateUrl.isNotEmpty;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isUpdateAvailable)
                            _buildNavigationTile(
                              icon: Icons.system_update_outlined,
                              title: l10n.updateAvailable,
                              onTap: () => _openExternal(
                                context,
                                launch,
                                appConfig.config.updateUrl,
                              ),
                            ),
                          _buildNavigationTile(
                            icon: Icons.info_outline,
                            title: l10n.appVersion,
                            trailingText: version.isNotEmpty ? version : null,
                            chevron: false,
                            onTap: () {},
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.spaceXl),

            // 7. SIGN OUT BUTTON (with confirmation)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await ConfirmActionDialog.show(
                    context,
                    title: l10n.signOutConfirmTitle,
                    message: l10n.signOutConfirmMessage,
                  );
                  if (!confirmed || !context.mounted) return;
                  await LogoutHelper.performLogout(context);
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surfaceLayer1,
                  side: const BorderSide(color: AppColors.subtleHairline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
                icon: const Icon(
                  Icons.logout,
                  size: 18,
                  color: AppColors.danger,
                ),
                label: Text(
                  AppTypography.uppercaseLabel(l10n.signOut),
                  style: AppTypography.labelSm(isArabic: l10n.isArabic)
                      .copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.spaceLg),

            // 8. DELETE ACCOUNT (danger style, last)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DeleteAccountScreen(),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surfaceLayer1,
                  side: const BorderSide(color: AppColors.subtleHairline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.danger,
                ),
                label: Text(
                  AppTypography.uppercaseLabel(l10n.deleteAccount),
                  style: AppTypography.labelSm(isArabic: l10n.isArabic)
                      .copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.spaceLg),

            Center(
              child: Text(
                l10n.allRightsReserved,
                style: AppTypography.caption(
                  isArabic: l10n.isArabic,
                ).copyWith(color: AppColors.textPlaceholder),
              ),
            ),
            const SizedBox(height: AppSpacing.space3xl),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    String? trailingText,
    bool chevron = true,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.spaceMd,
            vertical: 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    IconTile(
                      icon: icon,
                      iconColor: AppColors.textSecondary,
                      size: 32,
                      iconSize: 18,
                      borderRadius: AppRadius.radiusSm,
                    ),
                    const SizedBox(width: AppSpacing.spaceMd),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.bodySm().copyWith(
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.spaceSm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (trailingText != null) ...[
                    Text(trailingText, style: AppTypography.bodyXs()),
                    const SizedBox(width: 4),
                  ],
                  if (chevron)
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens a legal page in the browser ([legal_links] guarantees `https`).
  Future<void> _openExternal(
    BuildContext context,
    LaunchUrl launch,
    String url,
  ) async {
    await openLegalPage(url, launch: launch);
  }
}
