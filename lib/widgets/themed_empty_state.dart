import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Centered "nothing here" state with an optional title and action.
class ThemedEmptyState extends StatelessWidget {
  const ThemedEmptyState({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  /// Already localised.
  final String message;
  final String? title;
  final IconData icon;

  /// Optional call to action, typically a [PrimaryButton] or [SecondaryButton].
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;

    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.marginMobile),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppIconSize.xl + 16,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.spaceMd),
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: AppTypography.headlineSm(isArabic: isArabic),
              ),
              const SizedBox(height: AppSpacing.spaceXs),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd(
                isArabic: isArabic,
              ).copyWith(color: AppColors.textMuted),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.spaceLg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
