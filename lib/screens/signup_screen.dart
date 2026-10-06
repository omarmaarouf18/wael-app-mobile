import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import '../core/error_messages.dart';
import '../core/external_links.dart';
import '../core/field_validators.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_config_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/password_rules.dart';
import '../widgets/primary_button.dart';
import '../widgets/themed_error_banner.dart';
import '../widgets/themed_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.launchUrl});

  /// Opens the terms link under the consent checkbox. Tests inject a mock.
  final LaunchUrl? launchUrl;

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
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _agreeToTerms = false;
  bool _obscurePassword = true;

  /// Form-level validation message (terms agreement); field errors render
  /// inline under each field. The banner stays for this and server errors.
  String? _validationError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _validationError = null);
    if (!_agreeToTerms) {
      setState(
        () => _validationError = ErrorMessages.agreeToTermsRequired(
          l10n.isArabic,
        ),
      );
      return;
    }
    // Inline per-field errors (blur via onUserInteraction, and here on
    // submit); the banner stays for server errors only.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.signup(
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/otp');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = Provider.of<AuthProvider>(context);

    final error = _validationError ?? auth.errorMessage;

    return AppShell(
      showBack: true,
      titleWidget: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.appTitle, style: AppTypography.headerWordmark()),
          Text(l10n.appSubtitle, style: AppTypography.headerEyebrow()),
        ],
      ),
      body: Center(
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
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: AutofillGroup(
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
                      focusNode: _nameFocus,
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          FieldValidators.required(v, isArabic: l10n.isArabic),
                      onFieldSubmitted: (_) => _emailFocus.requestFocus(),
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
                      focusNode: _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          FieldValidators.email(v, isArabic: l10n.isArabic),
                      onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                      prefixIcon: const Icon(
                        Icons.alternate_email,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spaceMd),

                    // Phone Number
                    ThemedTextField(
                      label: l10n.phoneNumber,
                      hintText: '+20 100 000 0000',
                      controller: _phoneController,
                      focusNode: _phoneFocus,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          FieldValidators.required(v, isArabic: l10n.isArabic),
                      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
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
                      focusNode: _passwordFocus,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      validator: (v) => FieldValidators.newPassword(
                        v,
                        isArabic: l10n.isArabic,
                      ),
                      onChanged: (_) => setState(() {}),
                      onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? l10n.showPassword
                            : l10n.hidePassword,
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18,
                          // Small icons use danger (WCAG AA).
                          color: _obscurePassword
                              ? AppColors.textTertiary
                              : AppColors.danger,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spaceSm),
                    PasswordRules(password: _passwordController.text),
                    const SizedBox(height: AppSpacing.spaceMd),

                    // Confirm Password
                    ThemedTextField(
                      label: l10n.confirmPassword,
                      hintText: '••••••••••••',
                      controller: _confirmPasswordController,
                      focusNode: _confirmFocus,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      validator: (v) => FieldValidators.confirmPassword(
                        v,
                        _passwordController.text,
                        isArabic: l10n.isArabic,
                      ),
                      onFieldSubmitted: (_) => _handleSignup(),
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
                    // Read the terms the checkbox agrees to (same server
                    // URL as the settings tile; hidden until configured).
                    _TermsLink(launchUrl: widget.launchUrl),
                    const SizedBox(height: AppSpacing.spaceLg),

                    // Server / validation error
                    if (error != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          bottom: AppSpacing.spaceSm,
                        ),
                        child: ThemedErrorBanner(
                          message: error,
                          // Only server errors can be retried; validation
                          // errors are fixed by editing the form.
                          onRetry: _validationError == null
                              ? _handleSignup
                              : null,
                        ),
                      ),

                    // Submit CTA (disabled until the honor-code box is ticked).
                    PrimaryButton(
                      text: AppTypography.uppercaseLabel(l10n.signUp),
                      isLoading: auth.isLoading,
                      onPressed: _agreeToTerms ? _handleSignup : null,
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
                                    color: AppColors.textPrimary,
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

/// Link under the consent checkbox to the terms page (CONTENT-GAPS row 26).
/// Hidden until the server configures the URL. Tests inject [launchUrl].
class _TermsLink extends StatelessWidget {
  const _TermsLink({this.launchUrl});

  final LaunchUrl? launchUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final termsUrl = context.watch<AppConfigProvider>().termsUrl;
    if (termsUrl.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: () async {
          final uri = Uri.tryParse(termsUrl);
          if (uri == null || uri.scheme != 'https') return;
          await (launchUrl ?? defaultLaunchUrl)(
            uri,
            mode: LaunchMode.externalApplication,
          );
        },
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.spaceXs,
          ),
        ),
        child: Text(
          l10n.readTerms,
          style: AppTypography.bodySm(
            isArabic: l10n.isArabic,
          ).copyWith(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
