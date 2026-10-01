import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Centered crimson spinner. The accessibility label defaults to the
/// localised "Loading..."; [label] adds visible text under the spinner.
class ThemedLoadingIndicator extends StatelessWidget {
  const ThemedLoadingIndicator({super.key, this.label, this.size = 32});

  /// Already localised; shown under the spinner.
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Semantics(
        label: label ?? l10n.loading,
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: const CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.crimson),
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: AppSpacing.spaceMd),
              ExcludeSemantics(
                child: Text(
                  label!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm(isArabic: l10n.isArabic),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
