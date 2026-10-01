import 'package:flutter/material.dart';

import '../core/error_messages.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/academy_catalog.dart';
import 'app_badge.dart';
import 'catalog_file_tile.dart';

/// Bottom sheet describing one PDF: badges, title, size, and why it cannot be
/// opened yet (not owned, or downloads are not available in this build).
Future<void> showFileDetailsSheet(
  BuildContext context, {
  required AcademyFile file,
  required bool locked,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      final isArabic = l10n.isArabic;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.subtleHairline,
                    borderRadius: AppRadius.radiusPill,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.spaceMd),
              Row(
                children: [
                  const AppBadge(
                    label: 'PDF',
                    accent: true,
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppBadge(
                    label: l10n.fileKind(file.kind),
                    subtle: true,
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.spaceSm),
              Text(
                file.title.resolve(isArabic),
                style: AppTypography.headlineSm(
                  isArabic: isArabic,
                ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                formatFileSize(file.sizeBytes),
                style: AppTypography.bodyXs(isArabic: isArabic),
              ),
              const SizedBox(height: AppSpacing.spaceLg),
              Row(
                children: [
                  Icon(
                    locked ? Icons.lock_outline : Icons.info_outline,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      locked
                          ? ErrorMessages.courseLocked(isArabic)
                          : l10n.downloadsSoon,
                      style: AppTypography.bodySm(isArabic: isArabic),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
