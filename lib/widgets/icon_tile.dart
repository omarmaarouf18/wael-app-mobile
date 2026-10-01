import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Rounded square with a centred icon: list leading icons, setting rows.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.iconColor = AppColors.textPrimary,
    this.background = AppColors.surfaceHigh,
    this.size = 36,
    this.iconSize = AppIconSize.md - 2,
    this.borderRadius = AppRadius.radiusMd,
    this.borderColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
  final double size;
  final double iconSize;
  final BorderRadius borderRadius;

  /// Optional 1px border.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: borderRadius,
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Icon(icon, size: iconSize, color: iconColor),
    );
  }
}
