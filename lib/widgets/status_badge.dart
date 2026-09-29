import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/payment_request.dart';

class StatusBadge extends StatelessWidget {
  final PaymentStatus status;
  final String? customLabel;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.status,
    this.customLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;
    String defaultText;
    IconData icon;

    switch (status) {
      case PaymentStatus.pending:
        bg = AppColors.statusPendingBg;
        border = AppColors.statusPending.withValues(alpha: 0.5);
        text = AppColors.statusPending;
        defaultText = 'PENDING VERIFICATION';
        icon = Icons.schedule;
        break;
      case PaymentStatus.approved:
        bg = AppColors.statusApprovedBg;
        border = AppColors.statusApproved.withValues(alpha: 0.5);
        text = AppColors.statusApproved;
        defaultText = 'APPROVED & VERIFIED';
        icon = Icons.check_circle_outline;
        break;
      case PaymentStatus.rejected:
        bg = AppColors.statusRejectedBg;
        border = AppColors.statusRejected.withValues(alpha: 0.5);
        text = AppColors.statusRejected;
        defaultText = 'REJECTED';
        icon = Icons.cancel_outlined;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.spaceSm : AppSpacing.spaceMd,
        vertical: compact ? AppSpacing.space2xs : AppSpacing.spaceXs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: text),
          const SizedBox(width: AppSpacing.spaceXs),
          Text(
            customLabel ?? defaultText,
            style: AppTypography.labelSm().copyWith(
              color: text,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
