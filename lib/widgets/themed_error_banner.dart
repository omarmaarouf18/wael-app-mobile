import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Persistent inline error. It stays until the caller removes it (unlike a
/// SnackBar), is announced to screen readers when it appears, and offers a
/// retry action when [onRetry] is set.
class ThemedErrorBanner extends StatelessWidget {
  const ThemedErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
  });

  /// Already localised and sanitised (see ErrorMessages).
  final String message;
  final VoidCallback? onRetry;

  /// Defaults to the localised "Retry".
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.spaceMd,
          end: AppSpacing.spaceSm,
          top: AppSpacing.spaceSm,
          bottom: AppSpacing.spaceSm,
        ),
        decoration: BoxDecoration(
          color: AppColors.dangerBg,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline,
              size: AppIconSize.md,
              color: AppColors.danger,
            ),
            const SizedBox(width: AppSpacing.spaceMd),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyMd(
                  isArabic: l10n.isArabic,
                ).copyWith(color: AppColors.textPrimary),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: AppSpacing.spaceSm),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  minimumSize: const Size(48, 48),
                ),
                child: Text(
                  retryLabel ?? l10n.retry,
                  style: AppTypography.labelMd(
                    isArabic: l10n.isArabic,
                  ).copyWith(color: AppColors.danger),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
