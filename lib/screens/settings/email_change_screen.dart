import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/account_provider.dart';
import '../../utils/logout_helper.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/otp_pin_input.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/themed_error_banner.dart';
import '../../widgets/themed_text_field.dart';

/// Email change in two steps (F-UX2 A4): the new address plus the current
/// password, then the code sent to the new address. Confirming ends every
/// session, so success shows a message and returns to login.
class EmailChangeScreen extends StatefulWidget {
  const EmailChangeScreen({super.key});

  @override
  State<EmailChangeScreen> createState() => _EmailChangeScreenState();
}

class _EmailChangeScreenState extends State<EmailChangeScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final account = context.read<AccountProvider>();
    final ok = await account.requestEmailChange(
      newEmail: email,
      currentPassword: password,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _codeSent = true;
      } else {
        _error = account.errorMessage;
      }
    });
  }

  Future<void> _confirm() async {
    final code = _codeController.text.trim();
    if (code.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final account = context.read<AccountProvider>();
    final ok = await account.confirmEmailChange(code: code);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = account.errorMessage;
      });
      return;
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        content: Text(l10n.emailChangedMessage),
      ),
    );
    // Every session (including this one) ended server-side: leave through
    // the normal sign-out path, which lands on login.
    await LogoutHelper.performLogout(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppShell(
      showBack: true,
      title: l10n.editEmailTitle,
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.marginMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_codeSent) ...[
              ThemedTextField(
                controller: _emailController,
                label: l10n.newEmailLabel,
                keyboardType: TextInputType.emailAddress,
                readOnly: _busy,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.spaceSm),
              ThemedTextField(
                controller: _passwordController,
                obscureText: true,
                hintText: l10n.currentPassword,
                readOnly: _busy,
                onFieldSubmitted: (_) => _sendCode(),
              ),
              const SizedBox(height: AppSpacing.spaceMd),
              PrimaryButton(
                text: l10n.sendCodeAction,
                isLoading: _busy,
                onPressed: _sendCode,
              ),
            ] else ...[
              Text(
                l10n.emailCodeSent,
                style: AppTypography.bodyMd(isArabic: l10n.isArabic),
              ),
              const SizedBox(height: AppSpacing.spaceMd),
              Directionality(
                textDirection: TextDirection.ltr,
                child: OtpPinInput(
                  controller: _codeController,
                  enabled: !_busy,
                  onCompleted: (_) => _confirm(),
                ),
              ),
              const SizedBox(height: AppSpacing.spaceMd),
              PrimaryButton(
                text: l10n.confirm,
                isLoading: _busy,
                onPressed: _confirm,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.spaceSm),
              ThemedErrorBanner(message: _error ?? ''),
            ],
          ],
        ),
      ),
    );
  }
}
