import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/error_messages.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../widgets/primary_button.dart';
import '../widgets/themed_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _agreeToTerms = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final l10n = AppLocalizations.of(context);
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.crimson,
          content: Text(ErrorMessages.agreeToTermsRequired(l10n.isArabic)),
        ),
      );
      return;
    }

    final fullName = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty ||
        password.isEmpty ||
        fullName.isEmpty ||
        phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.crimson,
          content: Text(ErrorMessages.allFieldsRequired(l10n.isArabic)),
        ),
      );
      return;
    }
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.crimson,
          content: Text(ErrorMessages.passwordMinLength(l10n.isArabic, 8)),
        ),
      );
      return;
    }
    if (password != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.crimson,
          content: Text(ErrorMessages.passwordMismatch(l10n.isArabic)),
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.signup(
      fullName: fullName,
      phone: phone,
      email: email,
      password: password,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/otp');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.voidCanvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.textSecondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              l10n.appTitle,
              style: AppTypography.headlineSm().copyWith(
                letterSpacing: 2.0,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              l10n.appSubtitle,
              style: AppTypography.academyEyebrow().copyWith(fontSize: 8),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
                vertical: AppSpacing.spaceLg,
              ),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.signUp,
                      style: AppTypography.headlineLg(isArabic: l10n.isArabic),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.admissionsNote,
                      style: AppTypography.bodySm(
                        isArabic: l10n.isArabic,
                      ).copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.spaceXl),

                    // Full Name
                    ThemedTextField(
                      label: l10n.fullName,
                      hintText: 'Jane Doe',
                      controller: _nameController,
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spaceMd),

                    // Email
                    ThemedTextField(
                      label: l10n.emailOrPhone,
                      hintText: 'name@example.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(
                        Icons.alternate_email,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spaceMd),

                    // Phone Number
                    ThemedTextField(
                      label: l10n.isArabic
                          ? 'رقم الهاتف المحمول'
                          : 'Phone Number',
                      hintText: '+20 100 000 0000',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(
                        Icons.phone_outlined,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spaceMd),

                    // Password
                    ThemedTextField(
                      label: l10n.password,
                      hintText: '••••••••••••',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18,
                          color: _obscurePassword
                              ? AppColors.textTertiary
                              : AppColors.crimson,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spaceMd),

                    // Confirm Password
                    ThemedTextField(
                      label: l10n.confirmPassword,
                      hintText: '••••••••••••',
                      controller: _confirmPasswordController,
                      obscureText: _obscurePassword,
                      prefixIcon: const Icon(
                        Icons.lock_reset_outlined,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spaceMd),

                    // Honor Code Checkbox
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _agreeToTerms,
                            activeColor: AppColors.crimson,
                            checkColor: AppColors.textPrimary,
                            side: const BorderSide(
                              color: AppColors.prominentBorder,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _agreeToTerms = val ?? true;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.spaceSm),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _agreeToTerms = !_agreeToTerms;
                              });
                            },
                            child: Text(
                              l10n.agreeToTerms,
                              style:
                                  AppTypography.bodySm(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.3,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.spaceLg),

                    // Server / validation error
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

                    // Submit CTA
                    PrimaryButton(
                      text: AppTypography.uppercaseLabel(l10n.signUp),
                      isLoading: auth.isLoading,
                      onPressed: _handleSignup,
                    ),
                    const SizedBox(height: AppSpacing.spaceLg),

                    // Back to Login Link
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            l10n.alreadyHaveAccount,
                            style: AppTypography.bodySm(
                              isArabic: l10n.isArabic,
                            ).copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(width: AppSpacing.spaceXs),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Text(
                              l10n.signInPrompt,
                              style:
                                  AppTypography.bodySm(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(
                                    color: AppColors.crimson,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spaceXl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
