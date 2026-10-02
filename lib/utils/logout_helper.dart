import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';

class LogoutHelper {
  LogoutHelper._();

  static Future<bool> performLogout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final confirmed = await authProvider.logout();
    if (context.mounted) {
      if (!confirmed) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.signOutUnconfirmed),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
    return confirmed;
  }
}
