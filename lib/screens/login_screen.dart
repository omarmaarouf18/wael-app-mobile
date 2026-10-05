import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/framed_poster_card.dart';
import '../widgets/language_toggle_chip.dart';
import '../widgets/primary_button.dart';
import '../widgets/themed_error_banner.dart';
import '../widgets/themed_text_field.dart';

/// Sign-in by email and password. The EL METR poster is shown here and
/// nowhere else; the character art stays on the other screens. Phone sign-in
/// is a later update, and there is no "remember me": the session is kept
/// until the student signs out.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacementNamed('/main');
    } else if (auth.status == AuthStatus.needsVerification) {
      Navigator.of(context).pushNamed('/otp');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    return AppShell(
      showHeader: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.marginMobile,
              vertical: AppSpacing.spaceSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Language chip, at the end edge.
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: LanguageToggleChip(
                    label: l10n.isArabic ? 'English' : 'العربية',
                    onTap: localeProvider.toggleLocale,
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceMd),

                // The poster, whole, in a framed card.
                FramedPosterCard(
                  imageAsset: AppConstants.imgPoster,
                  aspectRatio: AppConstants.posterAspectRatio,
                  maxHeightFraction: 0.45,
                  semanticLabel: l10n.appTitle,
                ),
                const SizedBox(height: AppSpacing.spaceLg),

                Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.signIn,
                          style: AppTypography.headlineMd(
                            isArabic: l10n.isArabic,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.spaceLg),

                        // Email (phone sign-in comes later)
                        ThemedTextField(
                          label: l10n.email,
                          hintText: 'name@example.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          prefixIcon: const Icon(
                            Icons.alternate_email,
                            size: 18,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.spaceMd),

                        // Password field
                        ThemedTextField(
                          label: l10n.password,
                          hintText: '••••••••••••',
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleLogin(),
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
                        const SizedBox(height: AppSpacing.spaceSm),

                        // Forgot password, at the end edge.
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushNamed('/forgot');
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                l10n.forgotPassword,
                                style: AppTypography.bodySm(
                                  isArabic: l10n.isArabic,
                                ).copyWith(color: AppColors.textMuted),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.spaceMd),

                        // Server / validation error
                        if (auth.errorMessage != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              bottom: AppSpacing.spaceSm,
                            ),
                            child: ThemedErrorBanner(
                              message: auth.errorMessage!,
                              onRetry: _handleLogin,
                            ),
                          ),

                        // Sign In CTA
                        PrimaryButton(
                          text: AppTypography.uppercaseLabel(l10n.signIn),
                          isLoading: auth.isLoading,
                          onPressed: _handleLogin,
                        ),
                        const SizedBox(height: AppSpacing.spaceLg),

                        // Create Account Footer Link
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                l10n.dontHaveAccount,
                                style: AppTypography.bodySm(
                                  isArabic: l10n.isArabic,
                                ).copyWith(color: AppColors.textMuted),
                              ),
                              const SizedBox(width: AppSpacing.spaceXs),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pushNamed('/signup');
                                },
                                child: Text(
                                  l10n.createAccountPrompt,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
