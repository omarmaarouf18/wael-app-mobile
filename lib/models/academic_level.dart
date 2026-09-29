import 'subject.dart';

class AcademicLevel {
  final String id;
  final String categoryId;
  final String name;
  final String? nameAr;
  final String subtitle;
  final String? subtitleAr;
  final int order;
  final List<Subject> subjects;

  const AcademicLevel({
    required this.id,
    required this.categoryId,
    required this.name,
    this.nameAr,
    required this.subtitle,
    this.subtitleAr,
    required this.order,
    this.subjects = const [],
  });

  String localizedName(bool isArabic) =>
      (isArabic && nameAr != null && nameAr!.isNotEmpty) ? nameAr! : name;

  String localizedSubtitle(bool isArabic) =>
      (isArabic && subtitleAr != null && subtitleAr!.isNotEmpty)
      ? subtitleAr!
      : subtitle;

  int get subjectsCount => subjects.length;
}
