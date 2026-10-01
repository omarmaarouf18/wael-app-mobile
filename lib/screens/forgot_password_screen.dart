import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/otp_pin_input.dart';
import '../widgets/primary_button.dart';
import '../widgets/themed_error_banner.dart';
import '../widgets/themed_text_field.dart';

/// Two-phase password reset: request code → verify code → set new password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  int _step = 0;
  String? _resetToken;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.requestReset(_emailController.text);
    if (mounted) setState(() => _step = 1);
  }

  Future<void> _verify() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = await auth.verifyResetCode(
      email: _emailController.text,
      code: _codeController.text,
    );
    if (token != null && mounted) {
      setState(() {
        _resetToken = token;
        _step = 2;
      });
    }
  }

  Future<void> _confirm() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.confirmReset(
      resetToken: _resetToken ?? '',
      newPassword: _passwordController.text,
    );
    if (ok && mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final devOtp = auth.lastDevOtp;

    return AppShell(
      showBack: Navigator.of(context).canPop(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.marginMobile),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.resetPassword,
                  style: AppTypography.headlineMd(isArabic: l10n.isArabic),
                ),
                const SizedBox(height: AppSpacing.spaceSm),
                Text(
                  l10n.resetSentNote,
                  style: AppTypography.bodySm(
                    isArabic: l10n.isArabic,
                  ).copyWith(color: AppColors.textSecondary),
                ),
                if (kDebugMode &&
                    devOtp != null &&
                    devOtp.isNotEmpty &&
                    _step == 1) ...[
                  const SizedBox(height: AppSpacing.spaceMd),
                  Text(
                    'DEBUG OTP: $devOtp',
                    style: AppTypography.bodySm(
                      isArabic: l10n.isArabic,
                    ).copyWith(color: AppColors.crimson),
                  ),
                ],
                const SizedBox(height: AppSpacing.spaceLg),
                if (_step == 0) ...[
                  ThemedTextField(
                    label: l10n.emailOrPhone,
                    hintText: 'name@example.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),
                  PrimaryButton(
                    text: AppTypography.uppercaseLabel(l10n.sendCode),
                    isLoading: auth.isLoading,
                    onPressed: _request,
                  ),
                ],
                if (_step == 1) ...[
                  OtpPinInput(
                    controller: _codeController,
                    hasError: auth.errorMessage != null,
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),
                  PrimaryButton(
                    text: AppTypography.uppercaseLabel(l10n.verify),
                    isLoading: auth.isLoading,
                    onPressed: _verify,
                  ),
                ],
                if (_step == 2) ...[
                  ThemedTextField(
                    label: l10n.newPassword,
                    hintText: '••••••••',
                    controller: _passwordController,
                    obscureText: true,
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),
                  PrimaryButton(
                    text: AppTypography.uppercaseLabel(l10n.resetPassword),
                    isLoading: auth.isLoading,
                    onPressed: _confirm,
                  ),
                ],
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.spaceSm),
                  ThemedErrorBanner(
                    message: auth.errorMessage!,
                    onRetry: switch (_step) {
                      0 => _request,
                      1 => _verify,
                      _ => _confirm,
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
