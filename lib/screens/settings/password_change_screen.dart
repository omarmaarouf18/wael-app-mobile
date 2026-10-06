import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/error_messages.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/account_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/password_rules.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/themed_error_banner.dart';
import '../../widgets/themed_text_field.dart';

/// Password change (F-UX2 A2): the current password plus the new one twice,
/// with live rules. Success ends every other session and confirms.
class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});

  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final current = _currentController.text;
    final password = _newController.text;
    final confirm = _confirmController.text;
    if (current.isEmpty || password.isEmpty || _busy) return;
    if (password != confirm) {
      setState(() {
        _error = ErrorMessages.passwordMismatch(l10n.isArabic);
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final account = context.read<AccountProvider>();
    final ok = await account.changePassword(
      currentPassword: current,
      newPassword: password,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = account.errorMessage;
      });
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        content: Text(l10n.passwordChanged),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppShell(
      showBack: true,
      title: l10n.changePasswordTitle,
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.marginMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ThemedTextField(
              controller: _currentController,
              obscureText: true,
              hintText: l10n.currentPassword,
              readOnly: _busy,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.spaceSm),
            ThemedTextField(
              controller: _newController,
              obscureText: true,
              hintText: l10n.newPassword,
              readOnly: _busy,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),
            PasswordRules(password: _newController.text),
            const SizedBox(height: AppSpacing.spaceSm),
            ThemedTextField(
              controller: _confirmController,
              obscureText: true,
              hintText: l10n.confirmPassword,
              readOnly: _busy,
              onFieldSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.spaceSm),
              ThemedErrorBanner(message: _error ?? ''),
            ],
            const SizedBox(height: AppSpacing.spaceMd),
            PrimaryButton(text: l10n.save, isLoading: _busy, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
