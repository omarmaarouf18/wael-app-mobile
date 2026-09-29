enum AcademicMaterialType {
  book, // كتاب معتمد
  handout, // مذكرة دراسية
  summary, // ملخص مراجعة
  examDossier, // تطبيقات وبنك امتحانات
}

class AcademicMaterial {
  final String id;
  final String subjectId;
  final String subjectName;
  final String? subjectNameAr;
  final String levelName;
  final String? levelNameAr;
  final String title;
  final String? titleAr;
  final AcademicMaterialType type;
  final String fileFormat;
  final String fileSize;
  final int pageCount;
  final String author;
  final String? authorAr;
  final String coverImage;
  final String fileUrl;
  final bool isDownloaded;
  final String? description;
  final String? descriptionAr;

  const AcademicMaterial({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    this.subjectNameAr,
    this.levelName = 'الفرقة الثالثة',
    this.levelNameAr,
    required this.title,
    this.titleAr,
    required this.type,
    this.fileFormat = 'PDF',
    required this.fileSize,
    required this.pageCount,
    required this.author,
    this.authorAr,
    required this.coverImage,
    this.fileUrl = '',
    this.isDownloaded = false,
    this.description,
    this.descriptionAr,
  });

  String localizedTitle(bool isArabic) =>
      (isArabic && titleAr != null && titleAr!.isNotEmpty) ? titleAr! : title;

  String localizedSubject(bool isArabic) =>
      (isArabic && subjectNameAr != null && subjectNameAr!.isNotEmpty)
      ? subjectNameAr!
      : subjectName;

  String localizedLevel(bool isArabic) =>
      (isArabic && levelNameAr != null && levelNameAr!.isNotEmpty)
      ? levelNameAr!
      : levelName;

  String localizedAuthor(bool isArabic) =>
      (isArabic && authorAr != null && authorAr!.isNotEmpty)
      ? authorAr!
      : author;

  String localizedDescription(bool isArabic) =>
      (isArabic && descriptionAr != null && descriptionAr!.isNotEmpty)
      ? descriptionAr!
      : (description ?? '');

  String localizedType(bool isArabic) {
    switch (type) {
      case AcademicMaterialType.book:
        return isArabic ? 'كتاب معتمد' : 'Accredited Book';
      case AcademicMaterialType.handout:
        return isArabic ? 'مذكرة دراسية' : 'Study Handout';
      case AcademicMaterialType.summary:
        return isArabic ? 'ملخص مراجعة' : 'Revision Summary';
      case AcademicMaterialType.examDossier:
        return isArabic ? 'تطبيقات وامتحانات' : 'Exam Dossier';
    }
  }

  AcademicMaterial copyWith({
    String? id,
    String? subjectId,
    String? subjectName,
    String? subjectNameAr,
    String? levelName,
    String? levelNameAr,
    String? title,
    String? titleAr,
    AcademicMaterialType? type,
    String? fileFormat,
    String? fileSize,
    int? pageCount,
    String? author,
    String? authorAr,
    String? coverImage,
    String? fileUrl,
    bool? isDownloaded,
    String? description,
    String? descriptionAr,
  }) {
    return AcademicMaterial(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      subjectNameAr: subjectNameAr ?? this.subjectNameAr,
      levelName: levelName ?? this.levelName,
      levelNameAr: levelNameAr ?? this.levelNameAr,
      title: title ?? this.title,
      titleAr: titleAr ?? this.titleAr,
      type: type ?? this.type,
      fileFormat: fileFormat ?? this.fileFormat,
      fileSize: fileSize ?? this.fileSize,
      pageCount: pageCount ?? this.pageCount,
      author: author ?? this.author,
      authorAr: authorAr ?? this.authorAr,
      coverImage: coverImage ?? this.coverImage,
      fileUrl: fileUrl ?? this.fileUrl,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      description: description ?? this.description,
      descriptionAr: descriptionAr ?? this.descriptionAr,
    );
  }
}
