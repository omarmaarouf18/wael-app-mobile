import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// App title over the eyebrow flanked by two thin rules. Used in the main
/// shell header. Aligned to the start edge.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key});

  static const _rule = SizedBox(
    width: 12,
    height: 1,
    child: ColoredBox(color: AppColors.brandRule),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.appTitle, style: AppTypography.shellWordmark()),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _rule,
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
              child: Text(
                l10n.appSubtitle,
                style: AppTypography.shellEyebrow(),
              ),
            ),
            _rule,
          ],
        ),
      ],
    );
  }
}
