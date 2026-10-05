import 'dart:async' show TimeoutException;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_shell.dart';

/// Start gate: restores the stored session, then routes to home or login.
/// Static (no animations) so widget tests can settle.
///
/// The restore never hangs the splash: past [restoreBudget] the app enters
/// offline on the kept tokens (same branch as an unreachable server).
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.restoreBudget = const Duration(seconds: 20),
  });

  final Duration restoreBudget;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.tryRestore().timeout(widget.restoreBudget);
    } on TimeoutException {
      await auth.enterOffline();
    }
    if (!mounted) return;
    if (auth.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/main');
    } else if (auth.status == AuthStatus.needsVerification &&
        auth.pendingVerificationEmail != null) {
      Navigator.of(context).pushReplacementNamed('/otp');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppShell(
      showHeader: false,
      safeArea: false,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.appTitle,
              style: AppTypography.displayHero(isArabic: l10n.isArabic),
            ),
            Text(
              l10n.appSubtitle,
              style: AppTypography.academyEyebrow(isArabic: l10n.isArabic),
            ),
          ],
        ),
      ),
    );
  }
}
