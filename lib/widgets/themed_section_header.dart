import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Eyebrow-style section title with an optional end-aligned [action]
/// (for example a "View all" link). Latin titles are upper-cased through
/// [AppTypography.uppercaseLabel]; Arabic has no case and gets no letter
/// spacing, which would break its joined letterforms.
class ThemedSectionHeader extends StatelessWidget {
  const ThemedSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.uppercase = true,
  });

  /// Already localised.
  final String title;
  final Widget? action;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    final text = uppercase ? AppTypography.uppercaseLabel(title) : title;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.spaceSm),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: AppTypography.academyEyebrow(
                  isArabic: isArabic,
                ).copyWith(letterSpacing: isArabic ? 0 : null),
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
