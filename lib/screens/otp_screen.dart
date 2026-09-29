import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../widgets/primary_button.dart';
import '../widgets/themed_text_field.dart';

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

  @override
  void dispose() {
    _codeController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final devOtp = auth.lastDevOtp;

    return Scaffold(
      backgroundColor: AppColors.voidCanvas,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.marginMobile),
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
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.spaceSm),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        border: Border.all(color: AppColors.subtleHairline),
                      ),
                      child: Text(
                        'DEBUG OTP: $devOtp',
                        style: AppTypography.bodySm(
                          isArabic: l10n.isArabic,
                        ).copyWith(color: AppColors.crimson),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.spaceLg),
                  ThemedTextField(
                    label: l10n.verificationCode,
                    hintText: '123456',
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),
                  if (auth.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.spaceSm,
                      ),
                      child: Text(
                        auth.errorMessage!,
                        style: const TextStyle(color: AppColors.crimson),
                      ),
                    ),
                  PrimaryButton(
                    text: l10n.verify.toUpperCase(),
                    isLoading: auth.isLoading,
                    onPressed: _verify,
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
