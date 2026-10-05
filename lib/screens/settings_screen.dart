import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/logout_helper.dart';
import '../widgets/app_shell.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/icon_tile.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/themed_card.dart';
import '../widgets/themed_section_header.dart';

/// Settings tab. Everything here is real: the profile header is the signed-in
/// account (`GET /auth/me`: name, email, phone), the language switch changes
/// the app language (the choice is saved on the device and wins over the
/// device language), and sign out ends the session after a confirmation.
/// There are no other toggles.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final user = auth.currentUser;
    final name = user.fullName.trim();
    final phone = user.phone.trim();

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

            // 2. LANGUAGE
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

            // 3. SIGN OUT BUTTON (with confirmation)
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
