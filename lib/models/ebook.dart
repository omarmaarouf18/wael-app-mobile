class EBook {
  final String id;
  final String title;
  final String? titleAr;
  final String subtitle;
  final String? subtitleAr;
  final String author;
  final String? authorAr;
  final int pagesCount;
  final String fileSize;
  final String coverImagePath;
  final bool isOwned;
  final bool isLocked;
  final String description;
  final String? descriptionAr;
  final String pdfDownloadName;
  final List<String> chapters;
  final List<String>? chaptersAr;

  const EBook({
    required this.id,
    required this.title,
    this.titleAr,
    required this.subtitle,
    this.subtitleAr,
    required this.author,
    this.authorAr,
    required this.pagesCount,
    required this.fileSize,
    required this.coverImagePath,
    this.isOwned = true,
    this.isLocked = false,
    required this.description,
    this.descriptionAr,
    required this.pdfDownloadName,
    this.chapters = const [],
    this.chaptersAr,
  });

  String localizedTitle(bool isArabic) =>
      (isArabic && titleAr != null && titleAr!.isNotEmpty) ? titleAr! : title;

  String localizedSubtitle(bool isArabic) =>
      (isArabic && subtitleAr != null && subtitleAr!.isNotEmpty)
      ? subtitleAr!
      : subtitle;

  String localizedAuthor(bool isArabic) =>
      (isArabic && authorAr != null && authorAr!.isNotEmpty)
      ? authorAr!
      : author;

  String localizedDescription(bool isArabic) =>
      (isArabic && descriptionAr != null && descriptionAr!.isNotEmpty)
      ? descriptionAr!
      : description;

  List<String> localizedChapters(bool isArabic) =>
      (isArabic && chaptersAr != null && chaptersAr!.isNotEmpty)
      ? chaptersAr!
      : chapters;
}

class ChecklistItem {
  final String text;
  final bool isChecked;

  const ChecklistItem({required this.text, this.isChecked = false});
}

class StudyNote {
  final String id;
  final String title;
  final String? titleAr;
  final String course;
  final String? courseAr;
  final String date;
  final List<String> tags;
  final String content;
  final String? contentAr;
  final bool isPinned;
  final List<ChecklistItem>? checklistItems;

  const StudyNote({
    required this.id,
    required this.title,
    this.titleAr,
    required this.course,
    this.courseAr,
    required this.date,
    required this.tags,
    required this.content,
    this.contentAr,
    this.isPinned = false,
    this.checklistItems,
  });

  String localizedTitle(bool isArabic) =>
      (isArabic && titleAr != null && titleAr!.isNotEmpty) ? titleAr! : title;

  String localizedCourse(bool isArabic) =>
      (isArabic && courseAr != null && courseAr!.isNotEmpty)
      ? courseAr!
      : course;

  String localizedContent(bool isArabic) =>
      (isArabic && contentAr != null && contentAr!.isNotEmpty)
      ? contentAr!
      : content;

  StudyNote copyWith({
    String? id,
    String? title,
    String? titleAr,
    String? course,
    String? courseAr,
    String? date,
    List<String>? tags,
    String? content,
    String? contentAr,
    bool? isPinned,
    List<ChecklistItem>? checklistItems,
  }) {
    return StudyNote(
      id: id ?? this.id,
      title: title ?? this.title,
      titleAr: titleAr ?? this.titleAr,
      course: course ?? this.course,
      courseAr: courseAr ?? this.courseAr,
      date: date ?? this.date,
      tags: tags ?? this.tags,
      content: content ?? this.content,
      contentAr: contentAr ?? this.contentAr,
      isPinned: isPinned ?? this.isPinned,
      checklistItems: checklistItems ?? this.checklistItems,
    );
  }
}
