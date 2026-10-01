import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Surface level of a [ThemedPanel].
enum PanelTone {
  /// Default content surface.
  base,

  /// One step above [base], for a panel nested in or sitting on a card.
  raised,

  /// Recessed, for wells such as input groups.
  inset,
}

/// Static bordered surface for grouping content. Unlike [ThemedCard] it is
/// never tappable and casts no shadow; use [ThemedCard] for interactive or
/// elevated content.
class ThemedPanel extends StatelessWidget {
  const ThemedPanel({
    super.key,
    required this.child,
    this.tone = PanelTone.base,
    this.padding = const EdgeInsetsDirectional.all(AppSpacing.spaceLg),
  });

  final Widget child;
  final PanelTone tone;
  final EdgeInsetsGeometry padding;

  Color get _background => switch (tone) {
    PanelTone.base => AppColors.surfaceLayer1,
    PanelTone.raised => AppColors.surfaceElevated,
    PanelTone.inset => AppColors.surfaceContainerLow,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _background,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.subtleHairline),
      ),
      child: child,
    );
  }
}
