class Lesson {
  final String id;
  final String courseId;
  final String title;
  final String? titleAr;
  final String duration;
  final int lessonNumber;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLocked;
  final String overview;
  final String? overviewAr;
  final List<String> maxims;
  final List<String>? maximsAr;
  final String videoPoster;

  const Lesson({
    required this.id,
    required this.courseId,
    required this.title,
    this.titleAr,
    required this.duration,
    required this.lessonNumber,
    this.isCompleted = false,
    this.isCurrent = false,
    this.isLocked = false,
    this.overview = '',
    this.overviewAr,
    this.maxims = const [],
    this.maximsAr,
    this.videoPoster = 'assets/images/placeholder_course.png',
  });

  String localizedTitle(bool isArabic) =>
      (isArabic && titleAr != null && titleAr!.isNotEmpty) ? titleAr! : title;

  String localizedOverview(bool isArabic) =>
      (isArabic && overviewAr != null && overviewAr!.isNotEmpty)
      ? overviewAr!
      : overview;

  List<String> localizedMaxims(bool isArabic) =>
      (isArabic && maximsAr != null && maximsAr!.isNotEmpty)
      ? maximsAr!
      : maxims;

  Lesson copyWith({
    String? id,
    String? courseId,
    String? title,
    String? titleAr,
    String? duration,
    int? lessonNumber,
    bool? isCompleted,
    bool? isCurrent,
    bool? isLocked,
    String? overview,
    String? overviewAr,
    List<String>? maxims,
    List<String>? maximsAr,
    String? videoPoster,
  }) {
    return Lesson(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      titleAr: titleAr ?? this.titleAr,
      duration: duration ?? this.duration,
      lessonNumber: lessonNumber ?? this.lessonNumber,
      isCompleted: isCompleted ?? this.isCompleted,
      isCurrent: isCurrent ?? this.isCurrent,
      isLocked: isLocked ?? this.isLocked,
      overview: overview ?? this.overview,
      overviewAr: overviewAr ?? this.overviewAr,
      maxims: maxims ?? this.maxims,
      maximsAr: maximsAr ?? this.maximsAr,
      videoPoster: videoPoster ?? this.videoPoster,
    );
  }
}

class CourseModule {
  final String id;
  final String title;
  final String? titleAr;
  final String statusTag;
  final bool isLocked;
  final List<Lesson> lessons;

  const CourseModule({
    required this.id,
    required this.title,
    this.titleAr,
    required this.statusTag,
    this.isLocked = false,
    required this.lessons,
  });

  String localizedTitle(bool isArabic) =>
      (isArabic && titleAr != null && titleAr!.isNotEmpty) ? titleAr! : title;
}
