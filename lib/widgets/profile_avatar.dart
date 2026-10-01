import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'status_dot.dart';

/// Circular avatar with a hairline ring and an optional badge dot at the top
/// end corner (mirrors in RTL).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.image,
    this.size = 56,
    this.showBadge = true,
  });

  final ImageProvider image;
  final double size;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.glassHairline),
            image: DecorationImage(image: image, fit: BoxFit.cover),
          ),
        ),
        if (showBadge)
          const PositionedDirectional(
            top: 2,
            end: 2,
            child: StatusDot(size: 8),
          ),
      ],
    );
  }
}
