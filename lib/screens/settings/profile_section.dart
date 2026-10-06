import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/account_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/themed_card.dart';
import '../../widgets/themed_error_banner.dart';
import '../../widgets/themed_section_header.dart';
import '../../widgets/themed_text_field.dart';

/// "My account" settings section (F-UX2 Part B): the name and phone rows.
/// Each opens a sheet with the new value plus the current password; the
/// server allows each field once every 30 days.
class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = context.watch<AuthProvider>().currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ThemedSectionHeader(title: l10n.myAccount),
        ThemedCard(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProfileRow(
                icon: Icons.person_outline,
                title: l10n.nameLabel,
                value: user.fullName,
                hint: l10n.changeOnceEvery30Days,
                onTap: () => showProfileEditSheet(
                  context: context,
                  title: l10n.editNameTitle,
                  initialValue: user.fullName,
                  isPhone: false,
                ),
              ),
              _ProfileRow(
                icon: Icons.phone_outlined,
                title: l10n.mobileNumber,
                value: user.phone,
                hint: l10n.changeOnceEvery30Days,
                onTap: () => showProfileEditSheet(
                  context: context,
                  title: l10n.editPhoneTitle,
                  initialValue: user.phone,
                  isPhone: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.spaceMd,
            vertical: AppSpacing.spaceMd,
          ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodySm().copyWith(
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        value.isNotEmpty ? value : '—',
                        textAlign: TextAlign.start,
                        style: AppTypography.bodyXs().copyWith(
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: AppTypography.caption(
                        isArabic: l10n.isArabic,
                      ).copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.spaceSm),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet editing one profile field plus the current password.
/// Returns after a successful save; failures stay on the sheet.
Future<void> showProfileEditSheet({
  required BuildContext context,
  required String title,
  required String initialValue,
  required bool isPhone,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (sheetContext) => _ProfileEditSheet(
      title: title,
      initialValue: initialValue,
      isPhone: isPhone,
    ),
  );
}

class _ProfileEditSheet extends StatefulWidget {
  const _ProfileEditSheet({
    required this.title,
    required this.initialValue,
    required this.isPhone,
  });

  final String title;
  final String initialValue;
  final bool isPhone;

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  late final TextEditingController _valueController = TextEditingController(
    text: widget.initialValue,
  );
  late final TextEditingController _passwordController =
      TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _valueController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _valueController.text.trim();
    final password = _passwordController.text;
    if (value.isEmpty || password.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final account = context.read<AccountProvider>();
    final updated = await account.updateProfile(
      fullName: widget.isPhone ? null : value,
      phone: widget.isPhone ? value : null,
      currentPassword: password,
    );
    if (!mounted) return;
    if (updated == null) {
      setState(() {
        _busy = false;
        _error = account.errorMessage;
      });
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        content: Text(AppLocalizations.of(context).profileUpdated),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: AppSpacing.marginMobile,
          end: AppSpacing.marginMobile,
          top: AppSpacing.spaceLg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.spaceLg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: AppTypography.headlineSm(isArabic: l10n.isArabic),
              ),
              const SizedBox(height: AppSpacing.spaceMd),
              Directionality(
                textDirection: widget.isPhone
                    ? TextDirection.ltr
                    : Directionality.of(context),
                child: ThemedTextField(
                  controller: _valueController,
                  keyboardType: widget.isPhone
                      ? TextInputType.phone
                      : TextInputType.name,
                  readOnly: _busy,
                  onFieldSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(height: AppSpacing.spaceSm),
              ThemedTextField(
                controller: _passwordController,
                obscureText: true,
                hintText: l10n.currentPassword,
                readOnly: _busy,
                onFieldSubmitted: (_) => _save(),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.spaceSm),
                ThemedErrorBanner(message: _error ?? ''),
              ],
              const SizedBox(height: AppSpacing.spaceMd),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.crimson,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : Text(
                          l10n.save,
                          style: AppTypography.labelMd(isArabic: l10n.isArabic),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
