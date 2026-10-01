import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/academy_catalog.dart';
import 'app_badge.dart';
import 'themed_card.dart';

/// Human-readable size: B, KB or MB with one decimal for MB.
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Row for one PDF (book or note) of a subject: PDF and kind badges, size,
/// title and a lock when the subject is not owned.
class CatalogFileTile extends StatelessWidget {
  const CatalogFileTile({
    super.key,
    required this.file,
    required this.locked,
    required this.onTap,
  });

  final AcademyFile file;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;

    return ThemedCard(
      onTap: onTap,
      padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const AppBadge(
                      label: 'PDF',
                      accent: true,
                      fontSize: 9,
                      padding: EdgeInsetsDirectional.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                    ),
                    AppBadge(
                      label: l10n.fileKind(file.kind),
                      subtle: true,
                      fontSize: 9,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                    ),
                    Text(
                      formatFileSize(file.sizeBytes),
                      style: AppTypography.labelSm(
                        isArabic: isArabic,
                      ).copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(
                locked ? Icons.lock_outline : Icons.file_download_outlined,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            file.title.resolve(isArabic),
            style: AppTypography.bodySm(isArabic: isArabic).copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  l10n.previewMaterial,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSm(isArabic: isArabic).copyWith(
                    color: AppColors.crimson,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward,
                size: 12,
                color: AppColors.crimson,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
