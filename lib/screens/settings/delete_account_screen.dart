import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/external_links.dart' show LaunchUrl, defaultLaunchUrl;
import '../../core/legal_links.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/academy_catalog_provider.dart';
import '../../providers/account_provider.dart';
import '../../utils/logout_helper.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/themed_error_banner.dart';
import '../../widgets/themed_text_field.dart';

/// Account deletion (F-UX2 A5): a strong warning naming the active subjects,
/// the 30-day grace and how to cancel, then the current password plus the
/// typed word "حذف". The button stays disabled until both are valid.
/// Success shows the purge date, then returns to login (all sessions end).
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key, this.launchUrl});

  /// Opens the how-to-delete web page. Tests inject a mock.
  final LaunchUrl? launchUrl;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _deletionDate;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _isValid(bool isArabic) {
    if (_passwordController.text.isEmpty) return false;
    final trimmed = _confirmController.text.trim();
    if (trimmed == 'حذف') return true;
    if (!isArabic && trimmed.toLowerCase() == 'delete') return true;
    return false;
  }

  Future<void> _request(bool isArabic) async {
    if (!_isValid(isArabic) || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final account = context.read<AccountProvider>();
    final date = await account.requestDeletion(
      currentPassword: _passwordController.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (date == null) {
        _error = account.errorMessage;
      } else {
        _deletionDate = date;
      }
    });
  }

  Future<void> _backToLogin() async {
    await LogoutHelper.performLogout(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subjects = context.watch<AcademyCatalogProvider>().ownedSubjects;
    final date = _deletionDate;
    final valid = _isValid(l10n.isArabic);
    return AppShell(
      showBack: true,
      title: l10n.deleteAccount,
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.marginMobile),
        child: date == null
            ? _RequestForm(
                passwordController: _passwordController,
                confirmController: _confirmController,
                busy: _busy,
                valid: valid,
                error: _error,
                launchUrl: widget.launchUrl,
                subjectNames: [
                  for (final s in subjects) s.title.resolve(l10n.isArabic),
                ],
                onChanged: () => setState(() {}),
                onSubmit: () => _request(l10n.isArabic),
              )
            : _ScheduledDone(date: date, onBackToLogin: _backToLogin),
      ),
    );
  }
}

class _RequestForm extends StatelessWidget {
  const _RequestForm({
    required this.passwordController,
    required this.confirmController,
    required this.busy,
    required this.valid,
    required this.error,
    required this.launchUrl,
    required this.subjectNames,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool busy;
  final bool valid;
  final String? error;
  final LaunchUrl? launchUrl;
  final List<String> subjectNames;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.deleteAccountWarning,
          style: AppTypography.bodyMd(
            isArabic: l10n.isArabic,
          ).copyWith(color: AppColors.danger),
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        if (subjectNames.isNotEmpty) ...[
          Text(
            l10n.deleteAccountLoseAccess,
            style: AppTypography.labelMd(isArabic: l10n.isArabic),
          ),
          const SizedBox(height: AppSpacing.spaceXs),
          for (final name in subjectNames)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: AppSpacing.spaceXs,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.book_outlined,
                    size: AppIconSize.sm,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.spaceXs),
                  Expanded(
                    child: Text(
                      name,
                      style: AppTypography.bodySm(isArabic: l10n.isArabic),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.spaceSm),
        ],
        Text(
          l10n.deleteAccountGrace,
          style: AppTypography.bodyMd(isArabic: l10n.isArabic),
        ),
        // The web how-to page (always available, like terms/privacy).
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => openLegalPage(
              withUiLanguage(legalDeleteAccountUrl(), isArabic: l10n.isArabic),
              launch: launchUrl ?? defaultLaunchUrl,
            ),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.spaceXs,
              ),
            ),
            child: Text(
              l10n.deleteAccountWebHelp,
              style: AppTypography.bodySm(
                isArabic: l10n.isArabic,
              ).copyWith(color: AppColors.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
        ThemedTextField(
          controller: passwordController,
          obscureText: true,
          hintText: l10n.currentPassword,
          readOnly: busy,
          textInputAction: TextInputAction.next,
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: AppSpacing.spaceSm),
        ThemedTextField(
          controller: confirmController,
          hintText: l10n.deleteConfirmHint,
          readOnly: busy,
          textInputAction: TextInputAction.done,
          onChanged: (_) => onChanged(),
          onFieldSubmitted: (_) => onSubmit(),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.spaceSm),
          ThemedErrorBanner(message: error ?? ''),
        ],
        const SizedBox(height: AppSpacing.spaceMd),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: valid && !busy ? onSubmit : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.crimson,
              foregroundColor: AppColors.textPrimary,
              disabledBackgroundColor: AppColors.surfaceBright,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
            ),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textPrimary,
                    ),
                  )
                : Text(
                    l10n.deleteAccount,
                    style: AppTypography.labelMd(isArabic: l10n.isArabic),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ScheduledDone extends StatelessWidget {
  const _ScheduledDone({required this.date, required this.onBackToLogin});

  final String date;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.deletionScheduled(date),
          style: AppTypography.bodyMd(isArabic: l10n.isArabic),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
        SecondaryButton(text: l10n.backToLogin, onPressed: onBackToLogin),
      ],
    );
  }
}
