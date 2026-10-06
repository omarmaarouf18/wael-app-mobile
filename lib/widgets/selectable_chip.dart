import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Visual style of a [SelectableChip].
enum ChipVariant {
  /// Pill; the selected chip is filled crimson. Level and section pickers.
  filled,

  /// Rounded rectangle with a leading icon; the selected chip gets a crimson
  /// border and glow. Study-type picker.
  outlined,
}

/// A tappable chip that is either selected or not.
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.count,
    this.variant = ChipVariant.filled,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Optional small count shown after the label.
  final int? count;
  final ChipVariant variant;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    final outlined = variant == ChipVariant.outlined;
    final radius = outlined ? AppRadius.radiusLg : AppRadius.radiusPill;

    final Color background = outlined
        ? (selected ? AppColors.surfaceElevated : AppColors.surfaceContainerLow)
        : (selected ? AppColors.crimson : AppColors.surfaceContainerLow);
    final Color border = selected
        ? AppColors.crimson
        : AppColors.subtleHairline;
    final Color foreground = selected
        ? AppColors.textPrimary
        : AppColors.textSecondary;
    final Color iconColor = outlined
        // Small icons use danger (WCAG AA); fills and borders stay crimson.
        ? (selected ? AppColors.danger : AppColors.textMuted)
        : (selected ? AppColors.textPrimary : AppColors.textMuted);

    // 48x48 dp min tap target around a compact pill visual. The Align
    // factors keep the box hugging the visual (no full-width stretch) while
    // centering it in the target.
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Align(
              alignment: Alignment.center,
              widthFactor: 1.0,
              heightFactor: 1.0,
              child: AnimatedContainer(
                duration: AppMotion.durationFast,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: radius,
                  border: Border.all(
                    color: border,
                    width: outlined && selected ? 1.5 : 1.0,
                  ),
                  boxShadow: outlined && selected
                      ? AppElevation.crimsonGlow
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 14, color: iconColor),
                      SizedBox(width: outlined ? 8 : 6),
                    ],
                    Text(
                      label,
                      style: AppTypography.labelSm(isArabic: isArabic).copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.textPrimary.withValues(alpha: 0.2)
                              : AppColors.surfaceElevated,
                          borderRadius: AppRadius.radiusPill,
                        ),
                        child: Text(
                          '$count',
                          style: AppTypography.labelSm().copyWith(
                            color: selected
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
