import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Small filled circle: unread pips, live indicators, list bullets.
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    // Small indicators use danger (WCAG AA); fills stay crimson.
    this.color = AppColors.danger,
    this.size = 7,
    this.borderColor,
    this.borderWidth = 1.5,
  });

  final Color color;
  final double size;

  /// Optional ring, for example [AppColors.voidCanvas] to cut a pip out of the
  /// icon it badges.
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: borderWidth),
      ),
    );
  }
}
