import 'lesson.dart';

class Course {
  final String id;
  final String title;
  final String? titleAr;
  final String instructor;
  final String? instructorAr;
  final String category;
  final String? categoryAr;
  final int lessonsCount;
  final int hoursCount;
  final double rating;
  final int studentsCount;
  final int progress; // 0 - 100
  final bool isEnrolled;
  final String imagePath;
  final String description;
  final String? descriptionAr;
  final String level;
  final String tag;
  final int priceEgp;
  final List<CourseModule> modules;

  const Course({
    required this.id,
    required this.title,
    this.titleAr,
    required this.instructor,
    this.instructorAr,
    required this.category,
    this.categoryAr,
    required this.lessonsCount,
    required this.hoursCount,
    this.rating = 4.9,
    this.studentsCount = 1200,
    this.progress = 0,
    this.isEnrolled = false,
    required this.imagePath,
    required this.description,
    this.descriptionAr,
    this.level = 'Advanced',
    this.tag = 'Core Discipline',
    this.priceEgp = 1500,
    this.modules = const [],
  });

  String localizedTitle(bool isArabic) =>
      (isArabic && titleAr != null && titleAr!.isNotEmpty) ? titleAr! : title;

  String localizedInstructor(bool isArabic) =>
      (isArabic && instructorAr != null && instructorAr!.isNotEmpty)
      ? instructorAr!
      : instructor;

  String localizedCategory(bool isArabic) =>
      (isArabic && categoryAr != null && categoryAr!.isNotEmpty)
      ? categoryAr!
      : category;

  String localizedDescription(bool isArabic) =>
      (isArabic && descriptionAr != null && descriptionAr!.isNotEmpty)
      ? descriptionAr!
      : description;

  Course copyWith({
    String? id,
    String? title,
    String? titleAr,
    String? instructor,
    String? instructorAr,
    String? category,
    String? categoryAr,
    int? lessonsCount,
    int? hoursCount,
    double? rating,
    int? studentsCount,
    int? progress,
    bool? isEnrolled,
    String? imagePath,
    String? description,
    String? descriptionAr,
    String? level,
    String? tag,
    int? priceEgp,
    List<CourseModule>? modules,
  }) {
    return Course(
      id: id ?? this.id,
      title: title ?? this.title,
      titleAr: titleAr ?? this.titleAr,
      instructor: instructor ?? this.instructor,
      instructorAr: instructorAr ?? this.instructorAr,
      category: category ?? this.category,
      categoryAr: categoryAr ?? this.categoryAr,
      lessonsCount: lessonsCount ?? this.lessonsCount,
      hoursCount: hoursCount ?? this.hoursCount,
      rating: rating ?? this.rating,
      studentsCount: studentsCount ?? this.studentsCount,
      progress: progress ?? this.progress,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      imagePath: imagePath ?? this.imagePath,
      description: description ?? this.description,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      level: level ?? this.level,
      tag: tag ?? this.tag,
      priceEgp: priceEgp ?? this.priceEgp,
      modules: modules ?? this.modules,
    );
  }
}
