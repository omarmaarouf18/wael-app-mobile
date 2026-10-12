import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Light "updating" strip for a background refresh over data already on
/// screen (stable-release pass 2026-10-12): a 2 px bar while [active], an
/// equal empty space otherwise, so the content below never jumps.
class ThemedRefreshBar extends StatelessWidget {
  const ThemedRefreshBar({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 2,
      child: active
          ? Semantics(
              liveRegion: true,
              label: l10n.loading,
              child: const LinearProgressIndicator(
                key: ValueKey('refreshing_bar'),
                minHeight: 2,
                color: AppColors.crimson,
                backgroundColor: AppColors.surfaceElevated,
              ),
            )
          : null,
    );
  }
}
