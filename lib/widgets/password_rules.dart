import 'dart:convert' show utf8;

import 'package:flutter/material.dart';

import '../core/field_validators.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Live password rules shown under a new-password field: 8+ characters and
/// the 72-byte limit (Arabic counts as multi-byte; measured with [utf8]).
/// Each rule carries a check while unmet/meted so the state is not
/// color-only.
class PasswordRules extends StatelessWidget {
  const PasswordRules({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final longEnough = password.length >= FieldValidators.minPasswordLength;
    final shortEnough =
        utf8.encode(password).length <= FieldValidators.maxPasswordBytes;
    return Semantics(
      label: l10n.passwordRules,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Rule(met: longEnough, text: l10n.passwordRuleLength),
          const SizedBox(height: AppSpacing.spaceXs),
          _Rule(met: shortEnough, text: l10n.passwordRuleBytes),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.met, required this.text});

  final bool met;
  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle : Icons.circle_outlined,
          size: AppIconSize.xs,
          color: met ? AppColors.success : AppColors.textTertiary,
          semanticLabel: met ? l10n.ruleMet : l10n.ruleUnmet,
        ),
        const SizedBox(width: AppSpacing.spaceXs),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyXs(isArabic: l10n.isArabic).copyWith(
              color: met ? AppColors.textSecondary : AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}
