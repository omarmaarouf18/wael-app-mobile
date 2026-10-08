import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/error_messages.dart';
import '../core/external_links.dart';
import '../core/field_validators.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/legal_summary_sheet.dart';
import '../widgets/password_rules.dart';
import '../widgets/primary_button.dart';
import '../widgets/themed_error_banner.dart';
import '../widgets/themed_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.launchUrl});

  /// Opens the full legal pages from the summary sheet. Tests inject a mock.
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

  /// Opens the summary sheet. Tapping its agree button ticks the checkbox;
  /// any other dismissal leaves it as it was.
  Future<void> _openLegalSummary() async {
    final agreed = await showLegalSummarySheet(
      context,
      launchUrl: widget.launchUrl,
    );
    if (agreed && mounted) {
      setState(() => _agreeToTerms = true);
    }
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

                    // Consent checkbox: the two names are tappable links
                    // opening the summary sheet. Only the checkbox ticks
                    // it (or the sheet's agree button); tapping a link
                    // never toggles it.
                    _ConsentRow(
                      agreed: _agreeToTerms,
                      onTermsTap: _openLegalSummary,
                      onPrivacyTap: _openLegalSummary,
                      onChanged: (val) {
                        setState(() {
                          _agreeToTerms = val ?? true;
                        });
                      },
                    ),
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

/// Consent row: checkbox plus rich label with two tappable legal links.
/// Link taps open the summary sheet; they never toggle the checkbox.
///
/// The links are inline [WidgetSpan] buttons (not span recognizers): span
/// hit-testing does not resolve every RTL fragment, while box hit-testing
/// always lands, so every name stays tappable in both directions.
class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.agreed,
    required this.onTermsTap,
    required this.onPrivacyTap,
    required this.onChanged,
  });

  final bool agreed;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bodyStyle = AppTypography.bodySm(
      isArabic: l10n.isArabic,
    ).copyWith(color: AppColors.textSecondary, height: 1.3);
    final linkStyle = bodyStyle.copyWith(
      color: AppColors.textPrimary,
      decoration: TextDecoration.underline,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: agreed,
            activeColor: AppColors.crimson,
            checkColor: AppColors.textPrimary,
            side: const BorderSide(
              color: AppColors.prominentBorder,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.spaceSm),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: l10n.agreeToTermsPrefix,
              style: bodyStyle,
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: _InlineLink(
                    label: l10n.termsLinkLabel,
                    style: linkStyle,
                    onTap: onTermsTap,
                  ),
                ),
                TextSpan(text: l10n.agreeToTermsJoiner, style: bodyStyle),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: _InlineLink(
                    label: l10n.privacyLinkLabel,
                    style: linkStyle,
                    onTap: onPrivacyTap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Text(label, style: style),
      ),
    );
  }
}
