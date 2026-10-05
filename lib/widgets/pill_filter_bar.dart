import 'package:flutter/material.dart';
import '../core/theme.dart';

class FilterPillItem {
  final String id;
  final String label;
  final int? count;

  const FilterPillItem({required this.id, required this.label, this.count});
}

class PillFilterBar extends StatelessWidget {
  final List<FilterPillItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final EdgeInsetsGeometry padding;

  const PillFilterBar({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.marginMobile,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: items.map((item) {
          final isSelected = item.id == selectedId;
          final displayText = item.count != null
              ? '${item.label} (${item.count})'
              : item.label;

          return Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.spaceSm),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelected(item.id),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: AnimatedContainer(
                  duration: AppMotion.durationFast,
                  height: 34,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.spaceLg,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.crimson
                        : AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.crimson
                          : AppColors.subtleHairline,
                      width: 1,
                    ),
                    boxShadow: isSelected ? AppElevation.crimsonGlow : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    displayText,
                    style: AppTypography.labelSm().copyWith(
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
