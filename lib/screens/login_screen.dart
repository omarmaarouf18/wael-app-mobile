import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/primary_button.dart';
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

    return Scaffold(
      backgroundColor: AppColors.voidCanvas,
      body: Stack(
        children: [
          // Background Character Art with Noir Dissolution Gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.65,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  AppConstants.imgLoginPortrait,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.6),
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    AppConstants.imgCharacterArt,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.6),
                    errorBuilder: (ctx, err, st) =>
                        Container(color: AppColors.surfaceLayer1),
                  ),
                ),
                // Edge Vignette & Multi-stop Dissolution into #080808
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.25, 0.55, 0.85, 1.0],
                      colors: [
                        AppColors.scrimBlack.withValues(alpha: 0.35),
                        Colors.transparent,
                        AppColors.voidCanvas.withValues(alpha: 0.55),
                        AppColors.voidCanvas.withValues(alpha: 0.95),
                        AppColors.voidCanvas,
                      ],
                    ),
                  ),
                ),
                // Radial vignette
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2),
                      radius: 0.85,
                      colors: [
                        Colors.transparent,
                        AppColors.voidCanvas.withValues(alpha: 0.65),
                        AppColors.voidCanvas,
                      ],
                      stops: const [0.45, 0.75, 1.0],
                    ),
                  ),
                ),
              ],
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
                            // Language Toggle Button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => localeProvider.toggleLocale(),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.spaceMd,
                                    vertical: AppSpacing.spaceXs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLayer1.withValues(
                                      alpha: 0.85,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.pill,
                                    ),
                                    border: Border.all(
                                      color: AppColors.subtleHairline,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.language,
                                        size: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: AppSpacing.spaceXs),
                                      Text(
                                        l10n.isArabic ? 'English' : 'العربية',
                                        style: AppTypography.labelSm().copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Branding Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: size.height * 0.04,
                          bottom: AppSpacing.spaceLg,
                        ),
                        child: Column(
                          children: [
                            Text(
                              l10n.appTitle,
                              textAlign: TextAlign.center,
                              style:
                                  AppTypography.displayHero(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(
                                    fontSize: 32,
                                    letterSpacing: 6.0,
                                    shadows: const [
                                      Shadow(
                                        color: AppColors.scrimBlack,
                                        blurRadius: 16,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.appSubtitle,
                              textAlign: TextAlign.center,
                              style:
                                  AppTypography.academyEyebrow(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(
                                    fontSize: 11,
                                    letterSpacing: 4.5,
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.8,
                                    ),
                                    shadows: const [
                                      Shadow(
                                        color: AppColors.scrimBlack,
                                        blurRadius: 10,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
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
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.spaceSm,
                                  ),
                                  child: Text(
                                    auth.errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.crimson,
                                    ),
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
