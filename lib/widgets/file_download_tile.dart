import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/error_messages.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/academy_catalog.dart';
import '../providers/files_provider.dart';
import '../services/file_opener.dart';
import 'app_badge.dart';
import 'catalog_file_tile.dart' show formatFileSize;
import 'primary_button.dart';
import 'secondary_button.dart';
import 'themed_card.dart';

/// One PDF of an owned subject with its download state (SPEC Phase 5
/// client): Download; a progress bar with Cancel while it runs; then Open
/// (the phone's PDF app) and Share (system share sheet), which work
/// offline. A failure shows its localized message with Download again.
///
/// Use only for owned subjects with `features.files` on; locked subjects
/// keep [CatalogFileTile] (titles only, D4).
class FileDownloadTile extends StatelessWidget {
  const FileDownloadTile({
    super.key,
    required this.subject,
    required this.file,
  });

  final AcademySubject subject;
  final AcademyFile file;

  void _say(BuildContext context, String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _open(BuildContext context, FilesProvider files) async {
    final l10n = AppLocalizations.of(context);
    final result = await files.open(file.id);
    if (!context.mounted) return;
    switch (result) {
      case OpenResult.opened:
        return;
      case OpenResult.noApp:
        _say(
          context,
          l10n.noPdfApp,
          action: SnackBarAction(
            label: l10n.fileShare,
            onPressed: () => _share(context, files),
          ),
        );
      case OpenResult.failed:
        _say(context, l10n.fileOpenFailed);
    }
  }

  Future<void> _share(BuildContext context, FilesProvider files) async {
    final l10n = AppLocalizations.of(context);
    final result = await files.share(file.id, isArabic: l10n.isArabic);
    if (!context.mounted) return;
    if (result != OpenResult.opened) _say(context, l10n.fileOpenFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    final files = context.watch<FilesProvider>();
    final state = files.stateOf(file.id);
    final downloaded = files.isDownloaded(file.id);

    return ThemedCard(
      padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
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
              if (file.sizeBytes > 0)
                Text(
                  formatFileSize(file.sizeBytes),
                  style: AppTypography.labelSm(
                    isArabic: isArabic,
                  ).copyWith(color: AppColors.textMuted),
                ),
              if (downloaded && state.phase != FileDownloadPhase.downloading)
                AppBadge(
                  label: l10n.fileDownloaded,
                  subtle: true,
                  fontSize: 9,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
          const SizedBox(height: AppSpacing.spaceSm),
          switch (state.phase) {
            FileDownloadPhase.downloading => _progress(context, l10n, state),
            FileDownloadPhase.failed => _failed(context, l10n, files, state),
            FileDownloadPhase.idle =>
              downloaded
                  ? _ready(context, l10n, files)
                  : _downloadButton(l10n, files),
          },
        ],
      ),
    );
  }

  Widget _downloadButton(AppLocalizations l10n, FilesProvider files) =>
      SecondaryButton(
        key: ValueKey('download-${file.id}'),
        text: l10n.fileDownload,
        height: 44,
        leadingIcon: const Icon(Icons.file_download_outlined, size: 18),
        onPressed: () => files.download(subject, file),
      );

  Widget _ready(
    BuildContext context,
    AppLocalizations l10n,
    FilesProvider files,
  ) => Row(
    children: [
      Expanded(
        child: PrimaryButton(
          key: ValueKey('open-${file.id}'),
          text: l10n.fileOpen,
          height: 44,
          leadingIcon: const Icon(Icons.open_in_new, size: 18),
          onPressed: () => _open(context, files),
        ),
      ),
      const SizedBox(width: AppSpacing.spaceSm),
      Expanded(
        child: SecondaryButton(
          key: ValueKey('share-${file.id}'),
          text: l10n.fileShare,
          height: 44,
          leadingIcon: const Icon(Icons.share_outlined, size: 18),
          onPressed: () => _share(context, files),
        ),
      ),
    ],
  );

  Widget _progress(
    BuildContext context,
    AppLocalizations l10n,
    FileDownloadState state,
  ) {
    final fraction = state.fraction;
    final percent = fraction == null ? null : (fraction * 100).round();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: AppRadius.radiusPill,
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 6,
                  color: AppColors.crimson,
                  backgroundColor: AppColors.surfaceElevated,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.fileDownloading(percent),
                style: AppTypography.labelSm(
                  isArabic: l10n.isArabic,
                ).copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        IconButton(
          key: ValueKey('cancel-${file.id}'),
          tooltip: l10n.cancel,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => context.read<FilesProvider>().cancel(file.id),
        ),
      ],
    );
  }

  Widget _failed(
    BuildContext context,
    AppLocalizations l10n,
    FilesProvider files,
    FileDownloadState state,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              ErrorMessages.forFileDownload(
                state.error ?? const Object(),
                isArabic: l10n.isArabic,
              ),
              style: AppTypography.bodySm(
                isArabic: l10n.isArabic,
              ).copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.spaceSm),
      _downloadButton(l10n, files),
    ],
  );
}
