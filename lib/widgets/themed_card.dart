import 'package:flutter/material.dart';
import '../core/theme.dart';

class ThemedCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;
  final double borderRadius;
  final double borderWidth;
  final bool hasGlow;

  const ThemedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.spaceMd),
    this.backgroundColor = AppColors.surfaceLayer1,
    this.borderColor = AppColors.subtleHairline,
    this.borderRadius = AppRadius.card,
    this.borderWidth = 1.0,
    this.hasGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidget = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: hasGlow ? AppElevation.crimsonGlow : AppElevation.card,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: AppColors.crimson.withValues(alpha: 0.1),
          highlightColor: AppColors.surfaceHigh.withValues(alpha: 0.3),
          child: cardWidget,
        ),
      );
    }

    return cardWidget;
  }
}
