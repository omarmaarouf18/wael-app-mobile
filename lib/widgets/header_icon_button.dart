import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'status_dot.dart';

/// 36px circular icon button for screen headers, with an optional crimson pip
/// at the top end corner (mirrors in RTL).
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.showPip = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showPip;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusPill,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceLayer1,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.subtleHairline),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: AppIconSize.md - 2, color: AppColors.textPrimary),
            if (showPip)
              const PositionedDirectional(
                top: 7,
                end: 7,
                child: StatusDot(borderColor: AppColors.voidCanvas),
              ),
          ],
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
