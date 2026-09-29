import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/logout_helper.dart';
import '../widgets/themed_card.dart';
import '../widgets/primary_button.dart';
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
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.honorCodeAndTerms.toUpperCase(),
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
                l10n.isArabic
                    ? '١. كل دارس ملتحق بأكاديمية المتر ملزم بقواعد السيادة الأكاديمية والسرية المطلقة للمداولات.\n\n'
                          '٢. يمنع منعاً باتاً إعادة توزيع أو تسجيل مرافعات ودوسيهات المستشار وائل السعيد دون إذن رسمي مكتوب.\n\n'
                          '٣. الانضباط الحركي واللفظي، والحياد الانفعالي، والالتزام بأعلى معايير النزاهة القانونية شرط لاستمرار القيد.'
                    : '1. Every scholar enrolled in EL METR ACADEMY is bound by strict academic sovereignty and confidentiality.\n\n'
                          '2. Course materials, dossiers, and strategic debate recordings may not be redistributed without formal authorization from Counselor Wael El Saeed.\n\n'
                          '3. Intellectual rigor, measured composure, and unyielding discipline are mandatory across all deliberations.',
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
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: AppSpacing.marginMobile,
            right: AppSpacing.marginMobile,
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
                    l10n.editProfile.toUpperCase(),
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
                label: l10n.isArabic ? 'رقم الهاتف' : 'Phone Number',
                controller: phoneController,
              ),
              const SizedBox(height: AppSpacing.spaceLg),
              PrimaryButton(
                text: l10n.save.toUpperCase(),
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

    return Scaffold(
      backgroundColor: AppColors.voidCanvas,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
          vertical: AppSpacing.spaceMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. PROFILE HEADER CARD
            ThemedCard(
              padding: const EdgeInsets.all(AppSpacing.spaceMd),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar
                      Stack(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white12,
                                width: 1,
                              ),
                              image: const DecorationImage(
                                image: AssetImage(
                                  AppConstants.imgProfileAlexander,
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.crimson,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
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
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.crimson,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.isArabic
                                  ? 'دارس بالأكاديمية • دفعة ٢٠٢٤'
                                  : user.standing,
                              style:
                                  AppTypography.bodySm(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
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
                        l10n.editProfile.toUpperCase(),
                        style: AppTypography.labelSm(isArabic: l10n.isArabic)
                            .copyWith(
                              color: Colors.white,
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
            _buildSectionHeader(l10n.accountSecurity.toUpperCase()),
            const SizedBox(height: AppSpacing.spaceXs),
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
                          content: Text(
                            l10n.isArabic
                                ? 'التحقق بخطوتين مفعّل عبر الرمز المعتمد.'
                                : 'Two-Factor Authentication is active.',
                          ),
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
                          content: Text(
                            l10n.isArabic
                                ? 'يتم إرسال البيانات المعتمدة لبريدك الإلكتروني.'
                                : 'Dispatches sent to primary email line.',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.spaceLg),

            // 3. SECTION: LANGUAGE & PREFERENCES
            _buildSectionHeader(
              l10n.isArabic ? 'اللغة والتفضيلات' : 'LANGUAGE & PREFERENCES',
            ),
            const SizedBox(height: AppSpacing.spaceXs),
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
                            localeProvider.isArabic
                                ? 'تم تحويل اللغة إلى العربية (RTL)'
                                : 'Switched language to English (LTR)',
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
            _buildSectionHeader(l10n.notificationsSettings.toUpperCase()),
            const SizedBox(height: AppSpacing.spaceXs),
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
            _buildSectionHeader(
              l10n.isArabic
                  ? 'البروتوكول الأكاديمي والقانوني'
                  : 'Academy Protocol & Legal',
            ),
            const SizedBox(height: AppSpacing.spaceXs),
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
                          content: Text(
                            l10n.isArabic
                                ? 'سياسة الخصوصية الأكاديمية سارية وموثقة.'
                                : 'Privacy Protocol verified offline.',
                          ),
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
                  l10n.signOut.toUpperCase(),
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
                    style: AppTypography.academyEyebrow().copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 9,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'All rights reserved © 2026',
                    style: TextStyle(color: Color(0xFF404040), fontSize: 10),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Text(
        title,
        style: AppTypography.academyEyebrow().copyWith(
          color: AppColors.textTertiary,
          fontSize: 10,
          letterSpacing: 2.0,
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
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: iconColor ?? AppColors.textSecondary,
                  ),
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
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
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
                    Text(
                      trailingText,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
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
