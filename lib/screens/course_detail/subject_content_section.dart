import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/error_messages.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/academy_catalog.dart';
import '../../widgets/accent_title.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/catalog_file_tile.dart';
import '../../widgets/catalog_video_tile.dart';
import '../../widgets/file_details_sheet.dart';
import '../../widgets/selectable_chip.dart';
import '../../widgets/themed_empty_state.dart';
import '../../widgets/themed_panel.dart';
import '../../providers/academy_catalog_provider.dart';
import '../video_player_screen.dart';

enum _Section { videos, books, notes }

/// The subject's content: a segmented bar (videos, books, notes) over the
/// selected list. Every item is built from the subject detail the server sent;
/// access is decided here and only here:
///
/// - a video is locked unless the server marked it `playable` (the YouTube id
///   is never part of this data; it comes from a separate play request);
/// - files are locked unless the subject is owned.
class SubjectContentSection extends StatefulWidget {
  const SubjectContentSection({super.key, required this.detail});

  final AcademySubjectDetail detail;

  /// Whether [video] can be played by this student.
  static bool videoUnlocked(AcademySubjectDetail detail, AcademyVideo video) =>
      video.playable;

  @override
  State<SubjectContentSection> createState() => _SubjectContentSectionState();
}

class _SubjectContentSectionState extends State<SubjectContentSection> {
  _Section _selected = _Section.videos;

  /// Videos the player reported as not playable (a 404 on open or resume):
  /// shown locked at once, before the refreshed detail arrives.
  final Set<String> _lockedAfterPlayer = {};

  void _say(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openPlayer(AcademyVideo video) async {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    final navigator = Navigator.of(context);
    final catalog = context.read<AcademyCatalogProvider>();
    final subjectId = widget.detail.id;
    final exit = await navigator.pushNamed<Object?>(
      '/video-player',
      arguments: VideoPlayerArgs(
        videoId: video.id,
        title: video.title.resolve(isArabic),
        description: video.description.resolve(isArabic),
      ),
    );
    if (!mounted || exit != PlayerExit.locked) return;
    setState(() => _lockedAfterPlayer.add(video.id));
    catalog.loadDetail(subjectId, force: true);
    _say(context, ErrorMessages.courseLocked(isArabic));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = widget.detail;
    final books = detail.books;
    final notes = detail.notes;
    final total = detail.videos.length + books.length + notes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AccentTitle(
          title: l10n.subjectContent,
          trailing: AppBadge(
            label: l10n.itemsCount(total),
            pill: true,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 8,
              vertical: 2,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.spaceSm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              SelectableChip(
                label: l10n.tabVideos,
                icon: Icons.ondemand_video_outlined,
                count: detail.videos.length,
                selected: _selected == _Section.videos,
                onTap: () => setState(() => _selected = _Section.videos),
              ),
              const SizedBox(width: 8),
              SelectableChip(
                label: l10n.tabBooks,
                icon: Icons.menu_book_outlined,
                count: books.length,
                selected: _selected == _Section.books,
                onTap: () => setState(() => _selected = _Section.books),
              ),
              const SizedBox(width: 8),
              SelectableChip(
                label: l10n.tabMaterials,
                icon: Icons.description_outlined,
                count: notes.length,
                selected: _selected == _Section.notes,
                onTap: () => setState(() => _selected = _Section.notes),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        switch (_selected) {
          _Section.videos => _videos(context, l10n, detail),
          _Section.books => _files(
            context,
            l10n,
            detail,
            books,
            Icons.menu_book_outlined,
            l10n.emptyBooks,
          ),
          _Section.notes => _files(
            context,
            l10n,
            detail,
            notes,
            Icons.description_outlined,
            l10n.emptyMaterials,
          ),
        },
      ],
    );
  }

  bool _unlocked(AcademySubjectDetail detail, AcademyVideo video) =>
      SubjectContentSection.videoUnlocked(detail, video) &&
      !_lockedAfterPlayer.contains(video.id);

  Widget _empty(IconData icon, String message) => ThemedPanel(
    tone: PanelTone.inset,
    borderRadius: AppRadius.radiusLg,
    child: ThemedEmptyState(icon: icon, message: message),
  );

  Widget _videos(
    BuildContext context,
    AppLocalizations l10n,
    AcademySubjectDetail detail,
  ) {
    if (detail.videos.isEmpty) {
      return _empty(Icons.ondemand_video_outlined, l10n.emptyVideos);
    }
    final videos = [...detail.videos]
      ..sort((a, b) => a.position.compareTo(b.position));
    return Column(
      children: [
        for (final video in videos)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              bottom: AppSpacing.spaceSm,
            ),
            child: CatalogVideoTile(
              video: video,
              locked: !_unlocked(detail, video),
              onTap: () => _unlocked(detail, video)
                  ? _openPlayer(video)
                  : _say(context, ErrorMessages.courseLocked(l10n.isArabic)),
            ),
          ),
      ],
    );
  }

  Widget _files(
    BuildContext context,
    AppLocalizations l10n,
    AcademySubjectDetail detail,
    List<AcademyFile> files,
    IconData emptyIcon,
    String emptyMessage,
  ) {
    if (files.isEmpty) return _empty(emptyIcon, emptyMessage);
    return Column(
      children: [
        for (final file in files)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              bottom: AppSpacing.spaceSm,
            ),
            child: CatalogFileTile(
              file: file,
              locked: !detail.owned,
              onTap: () => showFileDetailsSheet(
                context,
                file: file,
                locked: !detail.owned,
              ),
            ),
          ),
      ],
    );
  }
}
