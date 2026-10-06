import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/error_messages.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/otp_pin_input.dart';
import '../widgets/primary_button.dart';
import '../widgets/themed_error_banner.dart';
import '../widgets/themed_panel.dart';

/// Email OTP verification after signup (or unverified login).
/// In debug builds the backend dev OTP is shown when present; release
/// builds never display it.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeController = TextEditingController();
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _codeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = auth.pendingVerificationEmail ?? '';
    final ok = await auth.verifyOtp(email: email, code: _codeController.text);
    if (ok && mounted) {
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = auth.pendingVerificationEmail ?? '';
    if (email.isEmpty) return;
    await auth.resendSignupOtp(email: email);
    if (!mounted) return;
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown -= 1);
      }
    });
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
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.verifyCode,
                    style: AppTypography.headlineMd(isArabic: l10n.isArabic),
                  ),
                  const SizedBox(height: AppSpacing.spaceSm),
                  Text(
                    auth.pendingVerificationEmail ?? '',
                    style: AppTypography.bodySm(
                      isArabic: l10n.isArabic,
                    ).copyWith(color: AppColors.textSecondary),
                  ),
                  if (kDebugMode && devOtp != null && devOtp.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.spaceMd),
                    ThemedPanel(
                      tone: PanelTone.inset,
                      padding: const EdgeInsetsDirectional.all(
                        AppSpacing.spaceSm,
                      ),
                      child: Text(
                        'DEBUG OTP: $devOtp',
                        style: AppTypography.bodySm(
                          isArabic: l10n.isArabic,
                        ).copyWith(color: AppColors.danger),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.spaceLg),
                  OtpPinInput(
                    controller: _codeController,
                    hasError: auth.errorMessage != null,
                    onSubmitted: (_) => _verify(),
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),
                  if (auth.errorMessage != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: AppSpacing.spaceSm,
                      ),
                      child: ThemedErrorBanner(
                        message: auth.errorMessage!,
                        onRetry: _verify,
                      ),
                    ),
                  PrimaryButton(
                    text: AppTypography.uppercaseLabel(l10n.verify),
                    isLoading: auth.isLoading,
                    onPressed: _verify,
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),
                  Center(
                    child: _resendCooldown > 0
                        ? Text(
                            ErrorMessages.resendCooldown(
                              l10n.isArabic,
                              _resendCooldown,
                            ),
                            style: AppTypography.bodySm(
                              isArabic: l10n.isArabic,
                            ).copyWith(color: AppColors.textSecondary),
                          )
                        : TextButton(
                            onPressed: auth.isLoading ? null : _resend,
                            child: Text(
                              l10n.resendCode,
                              style:
                                  AppTypography.bodySm(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
