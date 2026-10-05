import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'status_dot.dart';

/// Circular icon button for screen headers (36px visual on a 48x48 tap
/// target), with an optional crimson pip at the top end corner (mirrors in
/// RTL). Pass [tooltip] (or wrap in Semantics) so screen readers name every
/// icon-only button in ar and en.
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
    return _WithIcon(
      icon: icon,
      showPip: showPip,
      onTap: onTap,
      tooltip: tooltip,
    );
  }
}

/// 36px visual circle centred on the 48x48 tap target.
class _Circle extends StatelessWidget {
  const _Circle({required this.icon, required this.showPip});

  final IconData? icon;
  final bool showPip;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          if (icon != null)
            Icon(icon!, size: AppIconSize.md - 2, color: AppColors.textPrimary),
          if (showPip)
            const PositionedDirectional(
              top: 7,
              end: 7,
              child: StatusDot(borderColor: AppColors.voidCanvas),
            ),
        ],
      ),
    );
  }
}

class _WithIcon extends StatelessWidget {
  const _WithIcon({
    required this.icon,
    required this.showPip,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool showPip;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusPill,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: _Circle(icon: icon, showPip: showPip),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
