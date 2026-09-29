import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../l10n/app_localizations.dart';
import '../models/ebook.dart';
import '../providers/ebook_provider.dart';
import '../widgets/pill_filter_bar.dart';
import '../widgets/themed_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/themed_text_field.dart';

class EbookScreen extends StatefulWidget {
  const EbookScreen({super.key});

  @override
  State<EbookScreen> createState() => _EbookScreenState();
}

class _EbookScreenState extends State<EbookScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Checklist state for demo interactivity
  final List<bool> _checklist = [true, true, false];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openEbookReader(BuildContext context, EBook book) {
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.voidCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
        side: BorderSide(color: AppColors.subtleHairline, width: 1),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(AppSpacing.marginMobile),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: book.isOwned
                              ? AppColors.statusApprovedBg
                              : AppColors.statusRejectedBg,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          border: Border.all(
                            color: book.isOwned
                                ? AppColors.statusApproved
                                : AppColors.statusRejected,
                          ),
                        ),
                        child: Text(
                          book.isOwned
                              ? l10n.owned.toUpperCase()
                              : l10n.requiresEnrolment.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: book.isOwned
                                ? AppColors.statusApproved
                                : AppColors.statusRejected,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: AppColors.textSecondary,
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.spaceSm),

                  Text(
                    book.localizedTitle(l10n.isArabic),
                    style: AppTypography.headlineSm(
                      isArabic: l10n.isArabic,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.localizedAuthor(l10n.isArabic),
                    style: AppTypography.bodySm(isArabic: l10n.isArabic)
                        .copyWith(
                          color: AppColors.crimson,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),

                  // Metadata row
                  Row(
                    children: [
                      Text(
                        '${book.pagesCount} ${l10n.isArabic ? "صفحة" : "Pages"}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '•',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        book.fileSize,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.subtleHairline, height: 24),

                  // Description
                  Text(
                    book.localizedDescription(l10n.isArabic),
                    style: AppTypography.bodyMd(
                      isArabic: l10n.isArabic,
                    ).copyWith(height: 1.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.spaceLg),

                  // Table of contents / chapters
                  Text(
                    l10n.isArabic
                        ? 'فصول المصنف الأكاديمي:'
                        : 'Table of Contents:',
                    style: AppTypography.labelSm(isArabic: l10n.isArabic)
                        .copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.spaceSm),

                  ...book
                      .localizedChapters(l10n.isArabic)
                      .map(
                        (ch) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.bookmark_outline,
                                size: 14,
                                color: AppColors.crimson,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  ch,
                                  style: AppTypography.bodySm(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  const SizedBox(height: AppSpacing.spaceXl),

                  // Actions
                  PrimaryButton(
                    text: book.isOwned
                        ? (l10n.isArabic
                              ? 'فتح المذكرة للقراءة'
                              : 'OPEN IN VIEWER')
                        : l10n.enrollNow,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.surfaceElevated,
                          content: Text(
                            book.isOwned
                                ? (l10n.isArabic
                                      ? 'تم فتح مستند: ${book.pdfDownloadName}'
                                      : 'Reading mode active: ${book.pdfDownloadName}')
                                : (l10n.isArabic
                                      ? 'هذا الكتاب مخصص لدارسي المسار المتقدم.'
                                      : 'This publication requires active track enrolment.'),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.spaceLg),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openNewNoteModal(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.voidCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
        side: BorderSide(color: AppColors.subtleHairline, width: 1),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: AppSpacing.marginMobile,
            right: AppSpacing.marginMobile,
            top: AppSpacing.marginMobile,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.newNote.toUpperCase(),
                    style: AppTypography.headlineSm(
                      isArabic: l10n.isArabic,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.textSecondary,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.spaceMd),
              ThemedTextField(
                label: l10n.isArabic ? 'عنوان المذكرة' : 'Dossier Title',
                hintText: 'Core Observation...',
                controller: titleController,
              ),
              const SizedBox(height: AppSpacing.spaceMd),
              ThemedTextField(
                label: l10n.isArabic ? 'نص الملاحظة' : 'Dossier Content',
                hintText: 'Record observations or courtroom arguments...',
                controller: bodyController,
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.spaceLg),
              PrimaryButton(
                text: l10n.save.toUpperCase(),
                onPressed: () {
                  if (titleController.text.isNotEmpty) {
                    final ebookProvider = Provider.of<EBookProvider>(
                      context,
                      listen: false,
                    );
                    ebookProvider.addNote(
                      StudyNote(
                        id: 'note-${DateTime.now().millisecondsSinceEpoch}',
                        title: titleController.text,
                        course: 'Personal Study',
                        date: 'Just now',
                        tags: ['#Observation', '#Study'],
                        content: bodyController.text,
                      ),
                    );
                  }
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: AppSpacing.spaceLg),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ebookProvider = Provider.of<EBookProvider>(context);
    final books = ebookProvider.filteredEbooks;
    final notes = ebookProvider.filteredNotes;

    final filterPills = [
      FilterPillItem(
        id: 'all',
        label: l10n.allNotes,
        count: notes.length + books.length,
      ),
      FilterPillItem(id: 'ebooks', label: l10n.navEbooks, count: books.length),
      FilterPillItem(id: 'course', label: l10n.byCourse, count: 12),
      FilterPillItem(id: 'pinned', label: l10n.pinnedNotes, count: 4),
    ];

    return Scaffold(
      backgroundColor: AppColors.voidCanvas,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. SEARCH & NEW NOTE ACTION ROW
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.marginMobile,
                right: AppSpacing.marginMobile,
                top: AppSpacing.spaceMd,
                bottom: AppSpacing.spaceSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.subtleHairline),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.spaceMd,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            size: 20,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: AppSpacing.spaceSm),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: AppTypography.bodyMd().copyWith(
                                color: AppColors.textPrimary,
                              ),
                              onChanged: (val) =>
                                  ebookProvider.setSearchQuery(val),
                              cursorColor: AppColors.crimson,
                              decoration: InputDecoration(
                                hintText: l10n.isArabic
                                    ? 'ابحث في المذكرات والمؤلفات...'
                                    : 'Search notes, key ideas...',
                                hintStyle: AppTypography.bodyMd().copyWith(
                                  color: AppColors.textTertiary,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.spaceSm),
                  // New Note Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openNewNoteModal(context),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Ink(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.crimson,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: AppElevation.crimsonGlow,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.newNote,
                              style:
                                  AppTypography.labelSm(
                                    isArabic: l10n.isArabic,
                                  ).copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. FILTER PILLS
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.spaceXs),
              child: PillFilterBar(
                items: filterPills,
                selectedId: ebookProvider.activeFilter,
                onSelected: (val) => ebookProvider.setFilter(val),
              ),
            ),

            // 3. ACADEMY PUBLICATIONS / E-BOOKS SECTION
            if (ebookProvider.activeFilter == 'all' ||
                ebookProvider.activeFilter == 'ebooks') ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: AppSpacing.spaceSm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.ebooksTitle.toUpperCase(),
                        style: AppTypography.headlineSm(
                          isArabic: l10n.isArabic,
                        ).copyWith(fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.spaceSm),
                    Text(
                      '${books.length} ${l10n.isArabic ? "مؤلفات" : "Publications"}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(
                height: 170,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.marginMobile,
                  ),
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final book = books[index];
                    return Container(
                      width: 250,
                      margin: const EdgeInsets.only(right: AppSpacing.spaceMd),
                      child: ThemedCard(
                        onTap: () => _openEbookReader(context, book),
                        padding: const EdgeInsets.all(AppSpacing.spaceMd),
                        child: Row(
                          children: [
                            // Book Cover Mini
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: SizedBox(
                                width: 68,
                                height: 110,
                                child: Image.asset(
                                  book.coverImagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Image.asset(
                                        AppConstants.imgCardFront,
                                        fit: BoxFit.cover,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.spaceMd),
                            // Book Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    book.isOwned
                                        ? l10n.owned.toUpperCase()
                                        : l10n.requiresEnrolment.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: book.isOwned
                                          ? AppColors.statusApproved
                                          : AppColors.statusRejected,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    book.localizedTitle(l10n.isArabic),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        AppTypography.bodySm(
                                          isArabic: l10n.isArabic,
                                        ).copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    book.localizedAuthor(l10n.isArabic),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${book.pagesCount}p • ${book.fileSize}',
                                    style: const TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.spaceLg),
            ],

            // 4. PINNED NOTE SPOTLIGHT
            if (ebookProvider.activeFilter != 'ebooks') ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                ),
                child: ThemedCard(
                  padding: const EdgeInsets.all(AppSpacing.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.push_pin,
                                size: 15,
                                color: AppColors.crimson,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.isArabic ? 'قاعدة مثبتة' : 'PINNED MAXIM',
                                style: AppTypography.labelSm().copyWith(
                                  color: AppColors.crimson,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            '2h ago',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.isArabic
                            ? 'القاعدة الجوهرية: الانضباط والإيقاع في المناظرة'
                            : 'Core Maxim: Restraint & Cadence in Debate',
                        style: AppTypography.headlineSm(
                          isArabic: l10n.isArabic,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.isArabic
                            ? 'الدورة: البلاغة السيادية وفنون الإقناع'
                            : 'Course: Sovereign Rhetoric & Persuasion',
                        style: TextStyle(
                          color: AppColors.crimson.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.spaceSm),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.spaceMd),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: const Border(
                            left: BorderSide(
                              color: AppColors.crimson,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          l10n.isArabic
                              ? '“عند الحديث في البيئات عالية المخاطر، اخفض وتيرتك الصوتية ولا تعبث بالأكمام أو الساعة. السكون يفرض هيبة القاعة. انتظر ثانيتين من الصمت قبل الرد.”'
                              : '“When speaking in high-stakes environments, lower vocal cadence and do not fidget with cuffs or watch. Stillness dictates the room’s gravity. Allow 2 seconds of silence before counter-arguments.”',
                          style: AppTypography.bodyMd(isArabic: l10n.isArabic)
                              .copyWith(
                                color: Colors.white.withValues(alpha: 0.88),
                                height: 1.45,
                              ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.spaceSm),
                      Wrap(
                        spacing: 6,
                        children: ['#Rhetoric', '#Cadence', '#ExecutivePoise']
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceHigh,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xs,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.spaceLg),
            ],

            // 5. STUDY DOSSIER ENTRIES
            if (ebookProvider.activeFilter != 'ebooks') ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: AppSpacing.spaceSm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.studyDossier.toUpperCase(),
                      style: AppTypography.academyEyebrow(
                        isArabic: l10n.isArabic,
                      ).copyWith(letterSpacing: 2.0, fontSize: 10),
                    ),
                    Text(
                      '${notes.length} entries',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Note 1: Interactive Checklist
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: AppSpacing.spaceXs,
                ),
                child: ThemedCard(
                  padding: const EdgeInsets.all(AppSpacing.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.isArabic
                                      ? 'قائمة التحقق للخطاب الافتتاحي'
                                      : 'Checklist for Keynote Address',
                                  style:
                                      AppTypography.headlineSm(
                                        isArabic: l10n.isArabic,
                                      ).copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Personal Study • Yesterday',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.spaceSm),
                          const Icon(
                            Icons.more_horiz,
                            size: 18,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.spaceSm),
                      // Checklist items
                      ...[
                        l10n.isArabic
                            ? 'التحقق من تناسق الياقة واستقامة الثوب'
                            : 'Verify collar and lapel alignment',
                        l10n.isArabic
                            ? 'تثبيت التواصل البصري لمدة ٤ ثوانٍ كاملة مع رؤساء الجلسة'
                            : 'Establish unbroken 4-second baseline eye contact with floor leads',
                        l10n.isArabic
                            ? 'إلقاء الخاتمة دون أي كلمات تردد أو فواصل عشوائية'
                            : 'Deliver concluding thesis without filler pauses',
                      ].asMap().entries.map((entry) {
                        final i = entry.key;
                        final text = entry.value;
                        final checked = _checklist[i];

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _checklist[i] = !_checklist[i];
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: Checkbox(
                                    value: checked,
                                    activeColor: AppColors.crimson,
                                    checkColor: Colors.white,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onChanged: (val) {
                                      setState(() {
                                        _checklist[i] = val ?? false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.spaceSm),
                                Expanded(
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: checked
                                          ? AppColors.textTertiary
                                          : AppColors.textPrimary,
                                      decoration: checked
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Note 2: Framing Asymmetries
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: AppSpacing.spaceXs,
                ),
                child: ThemedCard(
                  padding: const EdgeInsets.all(AppSpacing.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.isArabic
                                      ? 'اختلالات التأطير في التفاوض'
                                      : 'Framing Asymmetries in Negotiations',
                                  style:
                                      AppTypography.headlineSm(
                                        isArabic: l10n.isArabic,
                                      ).copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Strategic Rhetoric • 3 days ago',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.spaceSm),
                          const Icon(
                            Icons.bookmark_border,
                            size: 18,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.spaceSm),
                      Text(
                        l10n.isArabic
                            ? 'إياك والتنازل عن الشروط الموضوعية دون استخلاص مكاسب إجرائية أولاً. وجّه التنازلات كمظهر من مظاهر الدبلوماسية لا كعلامة تردد.'
                            : 'Never concede terms without extracting procedural parity first. Frame concessions as deliberate diplomatic latitude rather than hesitation.',
                        style: AppTypography.bodySm(
                          isArabic: l10n.isArabic,
                        ).copyWith(color: AppColors.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: AppSpacing.spaceSm),
                      Wrap(
                        spacing: 6,
                        children: ['#Bargaining', '#Tactics']
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceHigh,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xs,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.space3xl),
          ],
        ),
      ),
    );
  }
}
