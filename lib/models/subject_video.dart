class SubjectVideo {
  final String id;
  final String subjectId;
  final String title;
  final String? titleAr;
  final String duration;
  final String videoUrl; // for future streaming / download integration
  final String thumbnailUrl;
  final int viewsCount;
  final String description;
  final String? descriptionAr;
  final bool isCompleted;

  const SubjectVideo({
    required this.id,
    required this.subjectId,
    required this.title,
    this.titleAr,
    required this.duration,
    this.videoUrl = '',
    required this.thumbnailUrl,
    this.viewsCount = 1420,
    this.description = '',
    this.descriptionAr,
    this.isCompleted = false,
  });

  String localizedTitle(bool isArabic) =>
      (isArabic && titleAr != null && titleAr!.isNotEmpty) ? titleAr! : title;

  String localizedDescription(bool isArabic) =>
      (isArabic && descriptionAr != null && descriptionAr!.isNotEmpty)
      ? descriptionAr!
      : description;

  SubjectVideo copyWith({
    String? id,
    String? subjectId,
    String? title,
    String? titleAr,
    String? duration,
    String? videoUrl,
    String? thumbnailUrl,
    int? viewsCount,
    String? description,
    String? descriptionAr,
    bool? isCompleted,
  }) {
    return SubjectVideo(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      titleAr: titleAr ?? this.titleAr,
      duration: duration ?? this.duration,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      viewsCount: viewsCount ?? this.viewsCount,
      description: description ?? this.description,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
