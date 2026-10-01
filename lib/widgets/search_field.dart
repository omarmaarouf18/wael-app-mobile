import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Rounded search box with a leading magnifier and a clear button that
/// appears once there is text.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;

    return Container(
      height: 48,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.spaceMd,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.subtleHairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.spaceSm),
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTypography.bodyMd(
                isArabic: isArabic,
              ).copyWith(color: AppColors.textPrimary),
              onChanged: onChanged,
              cursorColor: AppColors.crimson,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTypography.bodyMd(
                  isArabic: isArabic,
                ).copyWith(color: AppColors.textTertiary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: AppLocalizations.of(context).close,
                    icon: const Icon(Icons.close, size: 16),
                    color: AppColors.textTertiary,
                    onPressed: onClear,
                  ),
          ),
        ],
      ),
    );
  }
}
