import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../l10n/app_localizations.dart';
import '../models/course.dart';
import '../models/lesson.dart';
import '../models/subject.dart';
import '../models/subject_video.dart';
import '../models/academic_material.dart';
import '../providers/courses_provider.dart';
import '../providers/ebook_provider.dart';
import '../models/ebook.dart';
import '../widgets/primary_button.dart';
import '../widgets/themed_card.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  bool _isBookmarked = false;
  Lesson?
  _activeLesson; // If set, displays the integrated in-app video lesson experience!

  // Lesson player states
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  bool _showSubtitles = true;
  String _activeLessonTab = 'overview'; // 'overview', 'principles', 'resources'
  String _selectedSubjectSection =
      'classes'; // 'classes', 'videos', 'books', 'materials'

  void _openLessonViewer(Lesson lesson) {
    setState(() {
      _activeLesson = lesson;
      _isPlaying = true;
    });
  }

  void _closeLessonViewer() {
    setState(() {
      _activeLesson = null;
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final coursesProvider = Provider.of<CoursesProvider>(context);
    final subject = coursesProvider.getSubjectById(widget.courseId);
    final course =
        coursesProvider.getCourseById(widget.courseId) ??
        coursesProvider.allCourses.first;

    return Scaffold(
      backgroundColor: AppColors.voidCanvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.textSecondary,
          onPressed: () {
            if (_activeLesson != null) {
              _closeLessonViewer();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          _activeLesson != null
              ? '${l10n.isArabic ? "الدرس" : "Lesson"} ${_activeLesson!.lessonNumber}'
              : l10n.courseDossier.toUpperCase(),
          style: AppTypography.labelSm().copyWith(
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              size: 20,
              color: _isBookmarked
                  ? AppColors.crimson
                  : AppColors.textSecondary,
            ),
            onPressed: () {
              setState(() {
                _isBookmarked = !_isBookmarked;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.surfaceElevated,
                  duration: const Duration(seconds: 1),
                  content: Text(
                    _isBookmarked
                        ? (l10n.isArabic
                              ? 'تمت إضافة الدورة إلى العلامات المرجعية'
                              : 'Course saved to bookmarks')
                        : (l10n.isArabic
                              ? 'تمت إزالة العلامة المرجعية'
                              : 'Bookmark removed'),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            color: AppColors.textSecondary,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.surfaceElevated,
                  duration: const Duration(seconds: 1),
                  content: Text(
                    l10n.isArabic
                        ? 'تم نسخ رابط ملف الدورة إلى الحافظة'
                        : 'Course dossier link copied to clipboard',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _activeLesson != null
          ? _buildIntegratedLessonViewer(context, course, _activeLesson!, l10n)
          : _buildCourseOverview(context, course, subject, l10n),
    );
  }

  // ==========================================
  // VIEW 1: COURSE OVERVIEW & CURRICULUM
  // ==========================================
  Widget _buildCourseOverview(
    BuildContext context,
    Course course,
    Subject? subject,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HERO IMAGE BANNER
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.asset(
                  course.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    AppConstants.imgCharacterArt,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Noir Dissolution gradient
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0.0, 0.5, 1.0],
                      colors: [
                        AppColors.voidCanvas,
                        AppColors.voidCanvas.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Category Tag
              Positioned(
                top: 12,
                left: l10n.isArabic ? null : 16,
                right: l10n.isArabic ? 16 : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    course.tag.toUpperCase(),
                    style: AppTypography.labelSm().copyWith(
                      color: Colors.white,
                      fontSize: 9,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // Bottom stats bar
              Positioned(
                bottom: 12,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: AppColors.starRating,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            course.rating.toString(),
                            style: AppTypography.labelSm().copyWith(
                              color: AppColors.starRating,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '(${course.studentsCount} ${l10n.isArabic ? "دارس" : "Scholars"})',
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSm().copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.spaceSm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        border: Border.all(color: AppColors.subtleHairline),
                      ),
                      child: Text(
                        '${course.hoursCount} ${l10n.isArabic ? "ساعة تدريبية" : "Hours Total"}',
                        style: AppTypography.labelSm().copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 2. BRIEFING & INSTRUCTOR INFO
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.marginMobile,
              vertical: AppSpacing.spaceMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Red Accent
                Container(
                  width: 24,
                  height: 2,
                  color: AppColors.crimson,
                  margin: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
                ),
                Text(
                  course.localizedTitle(l10n.isArabic),
                  style: AppTypography.headlineMd(
                    isArabic: l10n.isArabic,
                  ).copyWith(fontWeight: FontWeight.w800, height: 1.2),
                ),
                const SizedBox(height: AppSpacing.spaceMd),

                // Instructor Dossier Card
                ThemedCard(
                  padding: const EdgeInsets.all(AppSpacing.spaceMd),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white12),
                          image: const DecorationImage(
                            image: AssetImage(AppConstants.imgCharacterArt),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  course.localizedInstructor(l10n.isArabic),
                                  style:
                                      AppTypography.bodyMd(
                                        isArabic: l10n.isArabic,
                                      ).copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.crimson,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.isArabic
                                  ? 'مستشار ومحكم دولي • عضو اتحاد المحامين العرب'
                                  : 'Counselor • International Arbitrator • Arab Lawyers Union',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  AppTypography.bodySm(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceMd),

                // Overview text
                Text(
                  course.localizedDescription(l10n.isArabic),
                  style: AppTypography.bodyMd(
                    isArabic: l10n.isArabic,
                  ).copyWith(color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: AppSpacing.spaceLg),

                // Primary CTA (Continue lesson if enrolled, or Enrol in program)
                PrimaryButton(
                  text: course.isEnrolled
                      ? l10n.continueLesson
                      : '${l10n.enrollNow} (${course.priceEgp} EGP)',
                  leadingIcon: Icon(
                    course.isEnrolled ? Icons.play_arrow : Icons.lock_open,
                    size: 18,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (course.isEnrolled) {
                      // Open Lesson 07
                      final lesson = const Lesson(
                        id: 'l7',
                        courseId: 'architectural-discipline',
                        title: 'The Power of Pauses & Strategic Stillness',
                        titleAr: 'قوة الصمت والتوقفات الاستراتيجية',
                        duration: '18:30',
                        lessonNumber: 7,
                        isCurrent: true,
                        overview:
                            'Dean El Metr analyzes the acute psychological tension created when an attorney refuses to fill an adversarial silence.',
                        videoPoster: AppConstants.imgFeaturedArchitectural,
                      );
                      _openLessonViewer(lesson);
                    } else {
                      // Navigate to payment
                      Navigator.of(
                        context,
                      ).pushNamed('/payment', arguments: course);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.spaceSm),

                // Secondary Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ThemedCard(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        onTap: () {
                          final ebookProvider = Provider.of<EBookProvider>(
                            context,
                            listen: false,
                          );
                          ebookProvider.addNote(
                            StudyNote(
                              id: 'note-${DateTime.now().millisecondsSinceEpoch}',
                              title: 'Observations on ${course.title}',
                              course: course.title,
                              date: 'Just now',
                              tags: ['#${course.tag}', '#Dossier'],
                              content:
                                  'Key observations recorded for this curriculum.',
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.surfaceElevated,
                              content: Text(
                                l10n.isArabic
                                    ? 'تم إنشاء مذكرة جديدة مرتبطة بهذه الدورة'
                                    : 'New study note created for this course',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.note_add_outlined,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                l10n.addToNotes,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    AppTypography.labelSm(
                                      isArabic: l10n.isArabic,
                                    ).copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.spaceSm),
                    Expanded(
                      child: ThemedCard(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.surfaceElevated,
                              content: Text(
                                l10n.isArabic
                                    ? 'تم تحميل المنهج الدراسي بنجاح للاطلاع دون اتصال'
                                    : 'Syllabus PDF downloaded for offline study',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.file_download_outlined,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                l10n.downloadSyllabus,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    AppTypography.labelSm(
                                      isArabic: l10n.isArabic,
                                    ).copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spaceXl),

                // 3. SUBJECT CONTENT (THE 4 ACADEMIC SECTIONS)
                _buildSubjectContentSections(context, course, subject, l10n),
                const SizedBox(height: AppSpacing.space2xl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SUBJECT CONTENT SECTIONS (4 ACADEMIC AREAS)
  // ==========================================
  Widget _buildSubjectContentSections(
    BuildContext context,
    Course course,
    Subject? subject,
    AppLocalizations l10n,
  ) {
    final classesList =
        subject?.classes ?? course.modules.expand((m) => m.lessons).toList();
    final videosList = subject?.videos ?? const <SubjectVideo>[];
    final booksList = subject?.books ?? const <AcademicMaterial>[];
    final materialsList = subject?.notes ?? const <AcademicMaterial>[];

    final totalCount =
        classesList.length +
        videosList.length +
        booksList.length +
        materialsList.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.crimson,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.subjectContent.toUpperCase(),
                  style: AppTypography.labelSm(isArabic: l10n.isArabic)
                      .copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.subtleHairline),
              ),
              child: Text(
                '$totalCount ${l10n.isArabic ? "محتوى" : "Items"}',
                style: AppTypography.labelSm().copyWith(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spaceSm),

        // 4 Sections Segmented Pill Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildSectionPill(
                id: 'classes',
                label: l10n.tabClasses,
                count: classesList.length,
                icon: Icons.school_outlined,
                l10n: l10n,
              ),
              const SizedBox(width: 8),
              _buildSectionPill(
                id: 'videos',
                label: l10n.tabVideos,
                count: videosList.length,
                icon: Icons.ondemand_video_outlined,
                l10n: l10n,
              ),
              const SizedBox(width: 8),
              _buildSectionPill(
                id: 'books',
                label: l10n.tabBooks,
                count: booksList.length,
                icon: Icons.menu_book_outlined,
                l10n: l10n,
              ),
              const SizedBox(width: 8),
              _buildSectionPill(
                id: 'materials',
                label: l10n.tabMaterials,
                count: materialsList.length,
                icon: Icons.description_outlined,
                l10n: l10n,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.spaceMd),

        // Active Section Content
        if (_selectedSubjectSection == 'classes')
          _buildClassesList(classesList, l10n)
        else if (_selectedSubjectSection == 'videos')
          _buildVideosList(videosList, l10n)
        else if (_selectedSubjectSection == 'books')
          _buildBooksList(context, booksList, l10n)
        else
          _buildMaterialsList(context, materialsList, l10n),
      ],
    );
  }

  Widget _buildSectionPill({
    required String id,
    required String label,
    required int count,
    required IconData icon,
    required AppLocalizations l10n,
  }) {
    final isSelected = _selectedSubjectSection == id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSubjectSection = id;
          });
        },
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: AppMotion.durationFast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.crimson
                : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: isSelected ? AppColors.crimson : AppColors.subtleHairline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.labelSm(isArabic: l10n.isArabic).copyWith(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassesList(List<Lesson> lessons, AppLocalizations l10n) {
    if (lessons.isEmpty) {
      return _buildEmptyContent(Icons.school_outlined, l10n.emptyClasses);
    }

    return Column(
      children: lessons.map((lesson) {
        final isPlayable = lesson.isCurrent || lesson.isCompleted;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
          child: ThemedCard(
            onTap: isPlayable ? () => _openLessonViewer(lesson) : null,
            padding: const EdgeInsets.all(AppSpacing.spaceMd),
            child: Row(
              children: [
                // Class status icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: lesson.isCurrent
                        ? AppColors.crimson.withValues(alpha: 0.15)
                        : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: lesson.isCurrent
                          ? AppColors.crimson
                          : AppColors.subtleHairline,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      lesson.isCompleted
                          ? '✓'
                          : (lesson.isCurrent ? '▶' : '${lesson.lessonNumber}'),
                      style: TextStyle(
                        color: lesson.isCurrent
                            ? AppColors.crimson
                            : (lesson.isCompleted
                                  ? AppColors.statusApproved
                                  : AppColors.textMuted),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.spaceMd),

                // Title & Duration
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.localizedTitle(l10n.isArabic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm(isArabic: l10n.isArabic)
                            .copyWith(
                              color: lesson.isCurrent
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: lesson.isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${l10n.isArabic ? "الحصة" : "Class"} ${lesson.lessonNumber} • ${lesson.duration}',
                        style: AppTypography.labelSm().copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Play icon
                Icon(
                  Icons.play_circle_fill,
                  size: 24,
                  color: isPlayable ? AppColors.crimson : AppColors.textMuted,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVideosList(List<SubjectVideo> videos, AppLocalizations l10n) {
    if (videos.isEmpty) {
      return _buildEmptyContent(
        Icons.ondemand_video_outlined,
        l10n.emptyVideos,
      );
    }

    return Column(
      children: videos.map((video) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
          child: ThemedCard(
            onTap: () {
              // Open integrated viewer with video details
              final tempLesson = Lesson(
                id: video.id,
                courseId: video.subjectId,
                title: video.title,
                titleAr: video.titleAr,
                duration: video.duration,
                lessonNumber: 1,
                isCurrent: true,
                overview: video.description,
                overviewAr: video.descriptionAr,
                videoPoster: video.thumbnailUrl,
              );
              _openLessonViewer(tempLesson);
            },
            padding: const EdgeInsets.all(AppSpacing.spaceMd),
            child: Row(
              children: [
                // Video thumbnail
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: SizedBox(
                        width: 72,
                        height: 48,
                        child: Image.asset(
                          video.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, st) => Container(
                            color: AppColors.surfaceHigh,
                            child: const Icon(
                              Icons.play_circle_outline,
                              color: AppColors.crimson,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          video.duration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.spaceMd),

                // Video title & views
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.localizedTitle(l10n.isArabic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm(isArabic: l10n.isArabic)
                            .copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${video.viewsCount} ${l10n.isArabic ? "مشاهدة" : "views"}',
                        style: AppTypography.labelSm().copyWith(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.play_arrow,
                  size: 20,
                  color: AppColors.crimson,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBooksList(
    BuildContext context,
    List<AcademicMaterial> books,
    AppLocalizations l10n,
  ) {
    if (books.isEmpty) {
      return _buildEmptyContent(Icons.menu_book_outlined, l10n.emptyBooks);
    }

    return Column(
      children: books.map((book) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
          child: ThemedCard(
            onTap: () => _showMaterialPreviewModal(context, book, l10n),
            padding: const EdgeInsets.all(AppSpacing.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.crimson.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            border: Border.all(
                              color: AppColors.crimson.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'PDF',
                            style: AppTypography.labelSm().copyWith(
                              color: AppColors.crimson,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${book.pageCount} ${l10n.isArabic ? "صفحة" : "pages"} • ${book.fileSize}',
                          style: AppTypography.labelSm().copyWith(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      book.isDownloaded
                          ? Icons.download_done
                          : Icons.file_download_outlined,
                      size: 16,
                      color: book.isDownloaded
                          ? AppColors.statusApproved
                          : AppColors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  book.localizedTitle(l10n.isArabic),
                  style: AppTypography.bodySm(isArabic: l10n.isArabic).copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  book.localizedAuthor(l10n.isArabic),
                  style: AppTypography.bodySm(
                    isArabic: l10n.isArabic,
                  ).copyWith(color: AppColors.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      l10n.previewMaterial,
                      style: AppTypography.labelSm(isArabic: l10n.isArabic)
                          .copyWith(
                            color: AppColors.crimson,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
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
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMaterialsList(
    BuildContext context,
    List<AcademicMaterial> materials,
    AppLocalizations l10n,
  ) {
    if (materials.isEmpty) {
      return _buildEmptyContent(
        Icons.description_outlined,
        l10n.emptyMaterials,
      );
    }

    return Column(
      children: materials.map((mat) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
          child: ThemedCard(
            onTap: () => _showMaterialPreviewModal(context, mat, l10n),
            padding: const EdgeInsets.all(AppSpacing.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.crimson.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            border: Border.all(
                              color: AppColors.crimson.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'PDF',
                            style: AppTypography.labelSm().copyWith(
                              color: AppColors.crimson,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Text(
                            mat.localizedType(l10n.isArabic),
                            style:
                                AppTypography.labelSm(
                                  isArabic: l10n.isArabic,
                                ).copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 9,
                                ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${mat.pageCount} ${l10n.isArabic ? "صفحة" : "pages"} • ${mat.fileSize}',
                          style: AppTypography.labelSm().copyWith(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      mat.isDownloaded
                          ? Icons.download_done
                          : Icons.file_download_outlined,
                      size: 16,
                      color: mat.isDownloaded
                          ? AppColors.statusApproved
                          : AppColors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  mat.localizedTitle(l10n.isArabic),
                  style: AppTypography.bodySm(isArabic: l10n.isArabic).copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  mat.localizedAuthor(l10n.isArabic),
                  style: AppTypography.bodySm(
                    isArabic: l10n.isArabic,
                  ).copyWith(color: AppColors.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      l10n.previewMaterial,
                      style: AppTypography.labelSm(isArabic: l10n.isArabic)
                          .copyWith(
                            color: AppColors.crimson,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
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
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyContent(IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.subtleHairline),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 36, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.spaceSm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodySm().copyWith(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaterialPreviewModal(
    BuildContext context,
    AcademicMaterial material,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.subtleHairline,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceMd),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.crimson.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        border: Border.all(
                          color: AppColors.crimson.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        material.fileFormat.toUpperCase(),
                        style: AppTypography.labelSm().copyWith(
                          color: AppColors.crimson,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(
                        material.localizedType(l10n.isArabic),
                        style: AppTypography.labelSm(isArabic: l10n.isArabic)
                            .copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spaceSm),
                Text(
                  material.localizedTitle(l10n.isArabic),
                  style: AppTypography.headlineSm(
                    isArabic: l10n.isArabic,
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '${material.localizedSubject(l10n.isArabic)} • ${material.localizedAuthor(l10n.isArabic)}',
                  style: AppTypography.bodySm(
                    isArabic: l10n.isArabic,
                  ).copyWith(color: AppColors.textMuted, fontSize: 11),
                ),
                const SizedBox(height: AppSpacing.spaceSm),
                Row(
                  children: [
                    Text(
                      '${material.pageCount} ${l10n.isArabic ? "صفحة" : "pages"} • ${material.fileSize}',
                      style: AppTypography.labelSm().copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spaceLg),
                PrimaryButton(
                  text: material.isDownloaded
                      ? (l10n.isArabic
                            ? 'الملف متوفر محلياً ✓'
                            : 'File Saved Offline ✓')
                      : '${l10n.downloadMaterial} (${material.fileSize})',
                  leadingIcon: Icon(
                    material.isDownloaded
                        ? Icons.check
                        : Icons.file_download_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    final ebookProvider = Provider.of<EBookProvider>(
                      context,
                      listen: false,
                    );
                    ebookProvider.toggleMaterialDownload(material.id);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.surfaceElevated,
                        content: Text(
                          l10n.isArabic
                              ? 'تم حفظ الملف بنجاح للاطلاع دون اتصال'
                              : 'File saved for offline reading',
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // VIEW 2: INTEGRATED IN-APP LESSON VIEWER
  // ==========================================
  Widget _buildIntegratedLessonViewer(
    BuildContext context,
    Course course,
    Lesson lesson,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simulated Noir Video Player Container
          Container(
            width: double.infinity,
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster
                  Image.asset(
                    lesson.videoPoster,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      AppConstants.imgFeaturedArchitectural,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Dark Vignette
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.5, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),

                  // Center Play/Pause Circle
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isPlaying = !_isPlaying;
                        });
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // Bottom Controls Overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.spaceMd,
                        vertical: AppSpacing.spaceSm,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.9),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Timeline bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: Container(
                              height: 3,
                              color: Colors.white24,
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: 0.25,
                                child: Container(color: AppColors.crimson),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Control items row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isPlaying = !_isPlaying;
                                      });
                                    },
                                    child: Icon(
                                      _isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.spaceSm),
                                  const Text(
                                    '04:15 / 18:30',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  // Speed button
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (_playbackSpeed == 1.0) {
                                          _playbackSpeed = 1.25;
                                        } else if (_playbackSpeed == 1.25) {
                                          _playbackSpeed = 1.5;
                                        } else if (_playbackSpeed == 1.5) {
                                          _playbackSpeed = 2.0;
                                        } else {
                                          _playbackSpeed = 1.0;
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white12,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.xs,
                                        ),
                                      ),
                                      child: Text(
                                        '${_playbackSpeed}x',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.spaceSm),
                                  // CC toggle
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _showSubtitles = !_showSubtitles;
                                      });
                                    },
                                    child: Icon(
                                      Icons.closed_caption_outlined,
                                      size: 18,
                                      color: _showSubtitles
                                          ? AppColors.crimson
                                          : AppColors.textTertiary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.spaceSm),
                                  // Fullscreen Simulation
                                  GestureDetector(
                                    onTap: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          backgroundColor:
                                              AppColors.surfaceElevated,
                                          duration: const Duration(seconds: 1),
                                          content: Text(
                                            l10n.isArabic
                                                ? 'محاكاة وضع الشاشة الكاملة داخل التطبيق'
                                                : 'Fullscreen video simulated in app shell',
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Icon(
                                      Icons.fullscreen,
                                      size: 18,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Subtitle box if active
          if (_showSubtitles)
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
                vertical: 8,
              ),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.subtleHairline),
              ),
              child: Text(
                l10n.isArabic
                    ? '“السكون والهدوء يحددان ثقل القاعة. امنح نفسك ثانيتين من الصمت قبل الشروع في دحض الحجة.”'
                    : '“Stillness dictates the room’s gravity. Allow 2 seconds of silence before counter-arguments.”',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

          // Lesson Details Section
          Padding(
            padding: const EdgeInsets.all(AppSpacing.marginMobile),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 2,
                  color: AppColors.crimson,
                  margin: const EdgeInsets.only(bottom: 6),
                ),
                Text(
                  lesson.localizedTitle(l10n.isArabic),
                  style: AppTypography.headlineSm(
                    isArabic: l10n.isArabic,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${course.localizedTitle(l10n.isArabic)} • ${course.localizedInstructor(l10n.isArabic)}',
                  style: AppTypography.bodySm(
                    isArabic: l10n.isArabic,
                  ).copyWith(color: AppColors.textMuted, fontSize: 11),
                ),
                const SizedBox(height: AppSpacing.spaceMd),

                // Tabs: Overview | Key Maxims | Resources
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildLessonTabButton('overview', l10n.tabOverview),
                      const SizedBox(width: AppSpacing.spaceLg),
                      _buildLessonTabButton('principles', l10n.tabKeyMaxims),
                      const SizedBox(width: AppSpacing.spaceLg),
                      _buildLessonTabButton(
                        'resources',
                        '${l10n.tabResources} (2)',
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.subtleHairline, height: 16),
                const SizedBox(height: AppSpacing.spaceSm),

                // Tab Content
                if (_activeLessonTab == 'overview') ...[
                  Text(
                    lesson.localizedOverview(l10n.isArabic),
                    style: AppTypography.bodyMd(
                      isArabic: l10n.isArabic,
                    ).copyWith(color: AppColors.textSecondary, height: 1.45),
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),
                  ThemedCard(
                    padding: const EdgeInsets.all(AppSpacing.spaceMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.isArabic
                              ? 'الأهداف التدريبية للدرس:'
                              : 'Core Lesson Objectives:',
                          style: AppTypography.labelSm(isArabic: l10n.isArabic)
                              .copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        ...[
                          l10n.isArabic
                              ? 'ترسيخ فجوة الصمت لثانيتين قبل الرد على الخصم'
                              : 'Establishing the 2-second pre-refutation void',
                          l10n.isArabic
                              ? 'التخلص التام من العبث بالأزرار أو الأكمام وساعات اليد'
                              : 'Eliminating fidgeting with cufflinks, pens, or watch dials',
                          l10n.isArabic
                              ? 'خفض الإيقاع الصوتي والسيطرة على وتيرة الاستجواب'
                              : 'Neutralizing cross-examination tempo by downward cadence',
                        ].map(
                          (bullet) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '• ',
                                  style: TextStyle(color: AppColors.crimson),
                                ),
                                Expanded(
                                  child: Text(
                                    bullet,
                                    style:
                                        AppTypography.bodySm(
                                          isArabic: l10n.isArabic,
                                        ).copyWith(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_activeLessonTab == 'principles') ...[
                  ...[
                    l10n.isArabic
                        ? '“الهاوي يتحدث لتبديد قلقه الداخلي. السيادي لا يتحدث إلا لتغيير ميزان القوى.”'
                        : '“The amateur speaks to relieve their own anxiety. The sovereign speaks only to shift the balance of power.”',
                    l10n.isArabic
                        ? '“حين تُجبر على الإجابة الفورية، خذ نفساً عميقاً هادئاً عبر الأنف قبل صياغة أطروحتك.”'
                        : '“When forced to answer immediately, breathe once through the nose before framing your thesis.”',
                  ].map(
                    (quote) => Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
                      padding: const EdgeInsets.all(AppSpacing.spaceMd),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.all(
                          Radius.circular(AppRadius.sm),
                        ),
                        border: Border(
                          left: BorderSide(color: AppColors.crimson, width: 2),
                        ),
                      ),
                      child: Text(
                        quote,
                        style: AppTypography.bodySm(isArabic: l10n.isArabic)
                            .copyWith(
                              fontStyle: FontStyle.italic,
                              color: Colors.white70,
                            ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Resources Tab
                  ThemedCard(
                    padding: const EdgeInsets.all(AppSpacing.spaceMd),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.surfaceElevated,
                          content: Text(
                            l10n.isArabic
                                ? 'تم حفظ ملخص الدرس السابع (PDF) في جهازك'
                                : 'Lesson 07 Dossier Briefing (PDF) saved locally',
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Text('📄', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: AppSpacing.spaceSm),
                              Expanded(
                                child: Text(
                                  l10n.isArabic
                                      ? 'ملف دراسة الدرس السابع (PDF)'
                                      : 'Lesson 07 Dossier Briefing (PDF)',
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySm(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.spaceSm),
                        const Text(
                          '1.2 MB',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spaceSm),
                  ThemedCard(
                    padding: const EdgeInsets.all(AppSpacing.spaceMd),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.surfaceElevated,
                          content: Text(
                            l10n.isArabic
                                ? 'تم حفظ التسجيل الصوتي للماستر كلاس (MP3)'
                                : 'Audio-Only Masterclass (MP3) saved offline',
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Text('🎙️', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: AppSpacing.spaceSm),
                              Expanded(
                                child: Text(
                                  l10n.isArabic
                                      ? 'التسجيل الصوتي الكامل (MP3)'
                                      : 'Audio-Only Masterclass (MP3)',
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySm(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.spaceSm),
                        const Text(
                          '18.4 MB',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.spaceLg),

                // Record Observation Button
                Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLayer1,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(
                      color: AppColors.crimson.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final ebookProvider = Provider.of<EBookProvider>(
                          context,
                          listen: false,
                        );
                        ebookProvider.addNote(
                          StudyNote(
                            id: 'note-${DateTime.now().millisecondsSinceEpoch}',
                            title: 'Note: ${lesson.title}',
                            course: course.title,
                            date: 'Just now',
                            tags: ['#Pauses', '#Cadence'],
                            content:
                                'Observation: 2-second silence before counter-arguments.',
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.surfaceElevated,
                            content: Text(
                              l10n.isArabic
                                  ? 'تم حفظ الملاحظة في قسم المذكرات'
                                  : 'Observation recorded in My Notes',
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.edit_note,
                            color: AppColors.crimson,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.recordObservation,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  AppTypography.labelSm(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceLg),

                // Previous & Next Lesson Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.surfaceElevated,
                            duration: const Duration(seconds: 1),
                            content: Text(
                              l10n.isArabic
                                  ? 'تحميل الدرس السابق...'
                                  : 'Loading previous lesson...',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      label: Text(
                        '${l10n.prevLesson}: L06',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.surfaceElevated,
                            duration: const Duration(seconds: 1),
                            content: Text(
                              l10n.isArabic
                                  ? 'تحميل الدرس التالي...'
                                  : 'Loading next lesson...',
                            ),
                          ),
                        );
                      },
                      label: Text(
                        '${l10n.nextLesson}: L08',
                        style: const TextStyle(
                          color: AppColors.crimson,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      icon: const Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: AppColors.crimson,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space3xl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonTabButton(String tabKey, String label) {
    final isSelected = _activeLessonTab == tabKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeLessonTab = tabKey;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.crimson : AppColors.textMuted,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 24,
            color: isSelected ? AppColors.crimson : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
