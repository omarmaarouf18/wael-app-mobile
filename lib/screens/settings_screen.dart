import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/logout_helper.dart';
import '../widgets/app_shell.dart';
import '../widgets/icon_tile.dart';
import '../widgets/primary_button.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/status_dot.dart';
import '../widgets/themed_card.dart';
import '../widgets/themed_section_header.dart';
import '../widgets/themed_text_field.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showHonorCodeModal(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.voidCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
        side: BorderSide(color: AppColors.subtleHairline, width: 1),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.marginMobile),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppTypography.uppercaseLabel(l10n.honorCodeAndTerms),
                    style: AppTypography.labelSm(
                      isArabic: l10n.isArabic,
                    ).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.textSecondary,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(color: AppColors.subtleHairline),
              const SizedBox(height: AppSpacing.spaceSm),
              Text(
                l10n.honorCodeBody,
                style: AppTypography.bodySm(
                  isArabic: l10n.isArabic,
                ).copyWith(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: AppSpacing.spaceXl),
            ],
          ),
        );
      },
    );
  }

  void _showEditProfileModal(BuildContext context, AppLocalizations l10n) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final nameController = TextEditingController(
      text: auth.currentUser.fullName,
    );
    final emailController = TextEditingController(text: auth.currentUser.email);
    final phoneController = TextEditingController(text: auth.currentUser.phone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.voidCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
        side: BorderSide(color: AppColors.subtleHairline, width: 1),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsetsDirectional.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            start: AppSpacing.marginMobile,
            end: AppSpacing.marginMobile,
            top: AppSpacing.marginMobile,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppTypography.uppercaseLabel(l10n.editProfile),
                    style: AppTypography.headlineSm(
                      isArabic: l10n.isArabic,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.textSecondary,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.spaceMd),
              ThemedTextField(label: l10n.fullName, controller: nameController),
              const SizedBox(height: AppSpacing.spaceMd),
              ThemedTextField(
                label: l10n.emailOrPhone,
                controller: emailController,
              ),
              const SizedBox(height: AppSpacing.spaceMd),
              ThemedTextField(
                label: l10n.phoneNumber,
                controller: phoneController,
              ),
              const SizedBox(height: AppSpacing.spaceLg),
              PrimaryButton(
                text: AppTypography.uppercaseLabel(l10n.save),
                onPressed: () {
                  auth.updateProfile(
                    auth.currentUser.copyWith(
                      fullName: nameController.text,
                      email: emailController.text,
                      phone: phoneController.text,
                    ),
                  );
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: AppSpacing.spaceLg),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final user = auth.currentUser;

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
            // 1. PROFILE HEADER CARD
            ThemedCard(
              padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar
                      const ProfileAvatar(
                        image: AssetImage(AppConstants.imgProfileDefault),
                      ),
                      const SizedBox(width: AppSpacing.spaceMd),

                      // User info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  user.fullName,
                                  style: AppTypography.headlineSm(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(fontWeight: FontWeight.bold),
                                ),
                                const StatusDot(size: 6),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.standingLabel(user.standing),
                              style: AppTypography.bodyXs(
                                isArabic: l10n.isArabic,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: AppTypography.bodyXs(
                                isArabic: l10n.isArabic,
                              ).copyWith(color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),
                  // Edit Profile Button
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditProfileModal(context, l10n),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceHigh,
                        side: const BorderSide(color: AppColors.subtleHairline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                      icon: const Icon(
                        Icons.edit,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      label: Text(
                        AppTypography.uppercaseLabel(l10n.editProfile),
                        style: AppTypography.labelSm(isArabic: l10n.isArabic)
                            .copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.spaceLg),

            // 2. SECTION: ACCOUNT & SECURITY
            ThemedSectionHeader(title: l10n.accountSecurity),
            ThemedCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.fingerprint,
                    iconColor: AppColors.crimson,
                    title: l10n.biometricSignIn,
                    value: settings.biometricEnabled,
                    onChanged: (_) => settings.toggleBiometric(),
                  ),
                  const Divider(color: AppColors.subtleHairline, indent: 48),
                  _buildNavigationTile(
                    icon: Icons.lock_outline,
                    title: l10n.passwordAnd2fa,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.surfaceElevated,
                          content: Text(l10n.twoFactorActive),
                        ),
                      );
                    },
                  ),
                  const Divider(color: AppColors.subtleHairline, indent: 48),
                  _buildNavigationTile(
                    icon: Icons.mail_outline,
                    title: l10n.emailCommunications,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.surfaceElevated,
                          content: Text(l10n.dispatchesToEmail),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.spaceLg),

            // 3. SECTION: LANGUAGE & PREFERENCES
            ThemedSectionHeader(title: l10n.languageAndPreferences),
            ThemedCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Immediate Language Switch Tile
                  _buildNavigationTile(
                    icon: Icons.language,
                    title: l10n.languageAndSubtitles,
                    trailingText: localeProvider.isArabic
                        ? 'العربية'
                        : 'English (US)',
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
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.spaceLg),

            // 4. SECTION: NOTIFICATIONS
            ThemedSectionHeader(title: l10n.notificationsSettings),
            ThemedCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.notifications_none,
                    title: l10n.liveEventReminders,
                    value: settings.eventReminders,
                    onChanged: (_) => settings.toggleReminders(),
                  ),
                  const Divider(color: AppColors.subtleHairline, indent: 48),
                  _buildSwitchTile(
                    icon: Icons.auto_stories_outlined,
                    title: l10n.curriculumUpdates,
                    value: settings.curriculumUpdates,
                    onChanged: (_) => settings.toggleUpdates(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.spaceLg),

            // 5. SECTION: ACADEMY PROTOCOL & LEGAL
            ThemedSectionHeader(title: l10n.academyProtocolLegal),
            ThemedCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildNavigationTile(
                    icon: Icons.verified_outlined,
                    title: l10n.honorCodeAndTerms,
                    onTap: () => _showHonorCodeModal(context, l10n),
                  ),
                  const Divider(color: AppColors.subtleHairline, indent: 48),
                  _buildNavigationTile(
                    icon: Icons.policy_outlined,
                    title: l10n.privacyPolicy,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.surfaceElevated,
                          content: Text(l10n.privacyVerified),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.spaceXl),

            // 6. SIGN OUT BUTTON
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => LogoutHelper.performLogout(context),
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
                  color: AppColors.crimson,
                ),
                label: Text(
                  AppTypography.uppercaseLabel(l10n.signOut),
                  style: AppTypography.labelSm(isArabic: l10n.isArabic)
                      .copyWith(
                        color: AppColors.crimson,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.spaceLg),

            // Sub-footer
            Center(
              child: Column(
                children: [
                  Text(
                    'EL METR ACADEMY iOS • ${AppConstants.appVersion}',
                    style: AppTypography.footerEyebrow(isArabic: l10n.isArabic),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.allRightsReserved,
                    style: AppTypography.caption(
                      isArabic: l10n.isArabic,
                    ).copyWith(color: AppColors.textPlaceholder),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space3xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceMd,
        vertical: 6,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                IconTile(
                  icon: icon,
                  iconColor: iconColor ?? AppColors.textSecondary,
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
          Switch(
            value: value,
            activeThumbColor: AppColors.crimson,
            activeTrackColor: AppColors.crimson.withValues(alpha: 0.3),
            inactiveThumbColor: AppColors.textMuted,
            inactiveTrackColor: AppColors.surfaceHigh,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    String? trailingText,
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
}
