import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/hero_backdrop.dart';
import '../widgets/language_toggle_chip.dart';
import '../widgets/primary_button.dart';
import '../widgets/themed_error_banner.dart';
import '../widgets/themed_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(
      _identifierController.text,
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
    final size = MediaQuery.of(context).size;

    return AppShell(
      showHeader: false,
      safeArea: false,
      body: Stack(
        children: [
          // Background character art dissolving into the canvas
          const PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: HeroBackdrop(
              imageAsset: AppConstants.imgLoginPortrait,
              fallbackAsset: AppConstants.imgCharacterArt,
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Top Bar with Language Selector
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.marginMobile,
                          vertical: AppSpacing.spaceSm,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            LanguageToggleChip(
                              label: l10n.isArabic ? 'English' : 'العربية',
                              onTap: localeProvider.toggleLocale,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Branding Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          top: size.height * 0.04,
                          bottom: AppSpacing.spaceLg,
                        ),
                        child: Column(
                          children: [
                            Text(
                              l10n.appTitle,
                              textAlign: TextAlign.center,
                              style: AppTypography.wordmarkTitle(
                                isArabic: l10n.isArabic,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.appSubtitle,
                              textAlign: TextAlign.center,
                              style: AppTypography.wordmarkSubtitle(
                                isArabic: l10n.isArabic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Spacer to push form nicely to lower portion
                    SliverToBoxAdapter(
                      child: SizedBox(height: size.height * 0.14),
                    ),

                    // Auth Form
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.marginMobile,
                          vertical: AppSpacing.spaceMd,
                        ),
                        child: Form(
                          key: _formKey,
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

                              // Email or Phone field
                              ThemedTextField(
                                label: l10n.emailOrPhone,
                                hintText: 'name@example.com',
                                controller: _identifierController,
                                keyboardType: TextInputType.emailAddress,
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

                              // Remember Me & Forgot Password Row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: GestureDetector(
                                      onTap: () {
                                        auth.setRememberMe(!auth.rememberMe);
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: Checkbox(
                                              value: auth.rememberMe,
                                              activeColor: AppColors.crimson,
                                              checkColor: AppColors.textPrimary,
                                              side: const BorderSide(
                                                color:
                                                    AppColors.prominentBorder,
                                                width: 1.5,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.xs,
                                                    ),
                                              ),
                                              onChanged: (val) {
                                                auth.setRememberMe(val ?? true);
                                              },
                                            ),
                                          ),
                                          const SizedBox(
                                            width: AppSpacing.spaceSm,
                                          ),
                                          Flexible(
                                            child: Text(
                                              l10n.rememberMe,
                                              style:
                                                  AppTypography.bodySm(
                                                    isArabic: l10n.isArabic,
                                                  ).copyWith(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.of(
                                        context,
                                      ).pushNamed('/forgot');
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Text(
                                        l10n.forgotPassword,
                                        style: AppTypography.bodySm(
                                          isArabic: l10n.isArabic,
                                        ).copyWith(color: AppColors.textMuted),
                                      ),
                                    ),
                                  ),
                                ],
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
                                        Navigator.of(
                                          context,
                                        ).pushNamed('/signup');
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
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
