import 'lesson.dart';
import 'subject_video.dart';
import 'academic_material.dart';

class Subject {
  final String id;
  final String categoryId; // 'lisence', 'diploma', 'vocational'
  final String levelId; // 'year_1', 'year_2', 'year_3', 'year_4'
  final String levelName;
  final String? levelNameAr;
  final String name;
  final String? nameAr;
  final String code; // e.g. "LAW-301"
  final String? term; // e.g. "الفصل الدراسي الأول"
  final String instructor;
  final String? instructorAr;
  final String description;
  final String? descriptionAr;
  final String imagePath;
  final int hoursCount;
  final double rating;
  final int studentsCount;
  final int progress; // 0 - 100
  final bool isEnrolled;
  final List<Lesson> classes; // الحصص
  final List<SubjectVideo> videos; // الفيديوهات
  final List<AcademicMaterial> books; // الكتب
  final List<AcademicMaterial> notes; // المذكرات والملفات التعليمية

  const Subject({
    required this.id,
    required this.categoryId,
    required this.levelId,
    required this.levelName,
    this.levelNameAr,
    required this.name,
    this.nameAr,
    required this.code,
    this.term,
    required this.instructor,
    this.instructorAr,
    required this.description,
    this.descriptionAr,
    required this.imagePath,
    this.hoursCount = 36,
    this.rating = 4.9,
    this.studentsCount = 1250,
    this.progress = 0,
    this.isEnrolled = false,
    this.classes = const [],
    this.videos = const [],
    this.books = const [],
    this.notes = const [],
  });

  String localizedName(bool isArabic) =>
      (isArabic && nameAr != null && nameAr!.isNotEmpty) ? nameAr! : name;

  String localizedLevel(bool isArabic) =>
      (isArabic && levelNameAr != null && levelNameAr!.isNotEmpty)
      ? levelNameAr!
      : levelName;

  String localizedInstructor(bool isArabic) =>
      (isArabic && instructorAr != null && instructorAr!.isNotEmpty)
      ? instructorAr!
      : instructor;

  String localizedDescription(bool isArabic) =>
      (isArabic && descriptionAr != null && descriptionAr!.isNotEmpty)
      ? descriptionAr!
      : description;

  bool get hasClasses => classes.isNotEmpty;
  bool get hasVideos => videos.isNotEmpty;
  bool get hasBooks => books.isNotEmpty;
  bool get hasNotes => notes.isNotEmpty;

  int get totalContentCount =>
      classes.length + videos.length + books.length + notes.length;

  Subject copyWith({
    String? id,
    String? categoryId,
    String? levelId,
    String? levelName,
    String? levelNameAr,
    String? name,
    String? nameAr,
    String? code,
    String? term,
    String? instructor,
    String? instructorAr,
    String? description,
    String? descriptionAr,
    String? imagePath,
    int? hoursCount,
    double? rating,
    int? studentsCount,
    int? progress,
    bool? isEnrolled,
    List<Lesson>? classes,
    List<SubjectVideo>? videos,
    List<AcademicMaterial>? books,
    List<AcademicMaterial>? notes,
  }) {
    return Subject(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      levelId: levelId ?? this.levelId,
      levelName: levelName ?? this.levelName,
      levelNameAr: levelNameAr ?? this.levelNameAr,
      name: name ?? this.name,
      nameAr: nameAr ?? this.nameAr,
      code: code ?? this.code,
      term: term ?? this.term,
      instructor: instructor ?? this.instructor,
      instructorAr: instructorAr ?? this.instructorAr,
      description: description ?? this.description,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      imagePath: imagePath ?? this.imagePath,
      hoursCount: hoursCount ?? this.hoursCount,
      rating: rating ?? this.rating,
      studentsCount: studentsCount ?? this.studentsCount,
      progress: progress ?? this.progress,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      classes: classes ?? this.classes,
      videos: videos ?? this.videos,
      books: books ?? this.books,
      notes: notes ?? this.notes,
    );
  }
}
