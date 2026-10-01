import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

/// Two-button confirmation dialog for actions that need a deliberate choice.
///
/// Tapping outside the dialog does not dismiss it. Use [show], which resolves
/// to true only when the user taps the confirm button.
class ConfirmActionDialog extends StatelessWidget {
  const ConfirmActionDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel,
    this.cancelLabel,
  });

  /// Already localised.
  final String title;
  final String message;

  /// Default to the localised "Confirm" and "Cancel".
  final String? confirmLabel;
  final String? cancelLabel;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmActionDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.radiusXl,
        side: BorderSide(color: AppColors.subtleHairline),
      ),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        label: title,
        explicitChildNodes: true,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.headlineSm(isArabic: l10n.isArabic),
              ),
              const SizedBox(height: AppSpacing.spaceSm),
              Text(
                message,
                style: AppTypography.bodyMd(isArabic: l10n.isArabic),
              ),
              const SizedBox(height: AppSpacing.spaceXl),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      text: cancelLabel ?? l10n.cancel,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.spaceMd),
                  Expanded(
                    child: PrimaryButton(
                      text: confirmLabel ?? l10n.confirm,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
