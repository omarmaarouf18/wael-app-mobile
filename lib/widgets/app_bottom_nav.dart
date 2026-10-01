import 'package:flutter/material.dart';

import '../core/theme.dart';

/// One destination of an [AppBottomNav].
class AppNavItem {
  const AppNavItem({required this.icon, required this.label});

  final IconData icon;

  /// Already localised; upper-cased for display.
  final String label;
}

/// Glass bottom navigation bar with a small crimson pin under the selected
/// item. Items are laid out from the start edge, so the order mirrors in RTL.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.navBarHeight,
      decoration: const BoxDecoration(
        color: AppColors.navBarGlass,
        border: Border(top: BorderSide(color: AppColors.glassHairline)),
        boxShadow: AppElevation.bottomNavSoft,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < items.length; i++)
              _NavButton(
                item: items[i],
                selected: i == currentIndex,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textPrimary : AppColors.textMuted;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 22, color: color),
              const SizedBox(height: 3),
              Text(
                AppTypography.uppercaseLabel(item.label),
                style: AppTypography.labelSm().copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 1.2,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: AppMotion.durationFast,
                width: selected ? 8 : 0,
                height: 2,
                decoration: BoxDecoration(
                  color: selected ? AppColors.crimson : Colors.transparent,
                  borderRadius: AppRadius.radiusPill,
                  boxShadow: selected ? AppElevation.crimsonGlow : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
