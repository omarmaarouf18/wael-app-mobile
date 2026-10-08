import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/error_messages.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/academy_catalog.dart';
import '../providers/academy_catalog_provider.dart';
import '../providers/app_config_provider.dart';
import '../providers/files_provider.dart';
import '../services/file_downloads.dart';
import '../widgets/app_badge.dart';
import '../widgets/app_shell.dart';
import '../widgets/file_download_tile.dart';
import '../widgets/themed_empty_state.dart';
import '../widgets/themed_error_banner.dart';
import '../widgets/themed_section_header.dart';
import '../widgets/themed_skeleton.dart';

/// Notes and books tab.
///
/// Behind the server flag `features.files` (client contract 2026-10-08,
/// server pending; missing, false or never fetched means off):
///
/// - off: the coming-soon state, titled with the tab name ([navNotes]); no
///   payment wording;
/// - on: "Notes & books": the files of every owned subject, grouped by
///   subject, each with Download / Open / Share ([FileDownloadTile]).
///   Downloaded copies are listed from the on-device index when the catalog
///   or a subject detail cannot be fetched, so they open offline.
class EbookScreen extends StatelessWidget {
  const EbookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final enabled = context.select<AppConfigProvider, bool>(
      (c) => c.filesEnabled,
    );
    return enabled ? const _NotesLibrary() : const _ComingSoon();
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppShell(
      showHeader: false,
      body: RefreshIndicator(
        color: AppColors.crimson,
        backgroundColor: AppColors.surfaceElevated,
        onRefresh: () async {},
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: SizedBox(
            height:
                MediaQuery.sizeOf(context).height - AppSpacing.headerHeight * 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppBadge(label: l10n.comingSoon, accent: true, pill: true),
                ThemedEmptyState(
                  icon: Icons.menu_book_outlined,
                  title: l10n.navNotes,
                  message: l10n.ebookComingSoon,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One subject's section in the library.
class _Group {
  _Group({
    required this.subject,
    required this.files,
    this.loading = false,
    this.error,
  });

  final AcademySubject subject;
  final List<AcademyFile> files;
  final bool loading;
  final Object? error;
}

class _NotesLibrary extends StatefulWidget {
  const _NotesLibrary();

  @override
  State<_NotesLibrary> createState() => _NotesLibraryState();
}

class _NotesLibraryState extends State<_NotesLibrary> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool force = false}) async {
    if (!mounted) return;
    final catalog = context.read<AcademyCatalogProvider>();
    if (force) {
      await catalog.reload();
    } else {
      await catalog.ensureLoaded();
    }
    if (!mounted) return;
    await Future.wait([
      for (final s in catalog.ownedSubjects)
        if (s.counts.books + s.counts.notes > 0)
          catalog.loadDetail(s.id, force: force),
    ]);
  }

  /// Owned subjects (server order) with their files: from the fresh detail
  /// when there is one, else from the downloaded copies. Copies of subjects
  /// the catalog does not list are shown only while the catalog is not a
  /// fresh server answer (offline, cached or failed).
  List<_Group> _groups(AcademyCatalogProvider catalog, FilesProvider files) {
    final bySubject = <String, List<DownloadedFile>>{};
    for (final d in files.downloads) {
      bySubject.putIfAbsent(d.subjectId, () => []).add(d);
    }
    final groups = <_Group>[];
    final listed = <String>{};
    for (final s in catalog.ownedSubjects) {
      listed.add(s.id);
      final state = catalog.detailOf(s.id);
      final detail = state.detail;
      final saved = bySubject[s.id] ?? const [];
      if (state.status == LoadStatus.ready && detail != null) {
        if (detail.owned && detail.files.isNotEmpty) {
          groups.add(_Group(subject: detail, files: detail.files));
        }
        continue;
      }
      final hasFiles = s.counts.books + s.counts.notes > 0;
      if (!hasFiles && saved.isEmpty) continue;
      groups.add(
        _Group(
          subject: s,
          files: [for (final d in saved) d.asFile],
          loading:
              state.status == LoadStatus.loading ||
              state.status == LoadStatus.idle,
          error: state.status == LoadStatus.error ? state.error : null,
        ),
      );
    }
    final fresh = catalog.isReady && !catalog.isStale;
    if (!fresh) {
      for (final e in bySubject.entries) {
        if (listed.contains(e.key)) continue;
        final first = e.value.first;
        groups.add(
          _Group(
            subject: AcademySubject(
              id: first.subjectId,
              levelKey: '-',
              term: '',
              title: first.subjectTitle,
              description: const LocalizedText(),
              owned: true,
              counts: const SubjectCounts(),
            ),
            files: [for (final d in e.value) d.asFile],
          ),
        );
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = context.watch<AcademyCatalogProvider>();
    final files = context.watch<FilesProvider>();
    final groups = _groups(catalog, files);

    final children = <Widget>[
      ThemedSectionHeader(title: l10n.navNotesAndBooks, uppercase: false),
    ];
    if (groups.isEmpty) {
      if (catalog.isLoading || catalog.status == LoadStatus.idle) {
        children.add(const ThemedSkeletonList());
      } else if (catalog.hasError) {
        children.add(
          ThemedErrorBanner(
            message: ErrorMessages.forCatalog(
              catalog.error ?? const Object(),
              isArabic: l10n.isArabic,
            ),
            onRetry: () => _load(force: true),
          ),
        );
      } else {
        children.add(
          ThemedEmptyState(
            icon: Icons.menu_book_outlined,
            message: l10n.filesEmpty,
          ),
        );
      }
    }
    for (final g in groups) {
      children.add(_SubjectFiles(group: g, onRetry: () => _load(force: true)));
    }

    return AppShell(
      showHeader: false,
      body: RefreshIndicator(
        color: AppColors.crimson,
        backgroundColor: AppColors.surfaceElevated,
        onRefresh: () => _load(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsetsDirectional.all(AppSpacing.marginMobile),
          children: children,
        ),
      ),
    );
  }
}

class _SubjectFiles extends StatelessWidget {
  const _SubjectFiles({required this.group, required this.onRetry});

  final _Group group;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = group.error;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: AppSpacing.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ThemedSectionHeader(
            title: group.subject.title.resolve(l10n.isArabic),
            uppercase: false,
          ),
          for (final f in group.files)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: AppSpacing.spaceXs,
              ),
              child: FileDownloadTile(subject: group.subject, file: f),
            ),
          if (group.files.isEmpty && group.loading)
            const ThemedSkeletonList(itemCount: 1),
          if (error != null && group.files.isEmpty)
            ThemedErrorBanner(
              message: ErrorMessages.forCatalog(error, isArabic: l10n.isArabic),
              onRetry: onRetry,
            ),
        ],
      ),
    );
  }
}
