import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'status_dot.dart';

/// Circular avatar with a hairline ring and an optional badge dot at the top
/// end corner (mirrors in RTL). Without an [image] it shows a neutral person
/// icon, so no stand-in photo is ever drawn.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.image,
    this.size = 56,
    this.showBadge = true,
  });

  final ImageProvider? image;
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
            image: image == null
                ? null
                : DecorationImage(image: image!, fit: BoxFit.cover),
          ),
          child: image == null
              ? Icon(
                  Icons.person_outline,
                  size: size * 0.5,
                  color: AppColors.textMuted,
                )
              : null,
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
