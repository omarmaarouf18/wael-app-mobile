import 'package:flutter/material.dart';
import 'academic_level.dart';

class EducationCategory {
  final String id; // 'lisence', 'diploma', 'vocational'
  final String name;
  final String? nameAr;
  final String description;
  final String? descriptionAr;
  final IconData icon;
  final List<AcademicLevel> levels;

  const EducationCategory({
    required this.id,
    required this.name,
    this.nameAr,
    required this.description,
    this.descriptionAr,
    required this.icon,
    this.levels = const [],
  });

  String localizedName(bool isArabic) =>
      (isArabic && nameAr != null && nameAr!.isNotEmpty) ? nameAr! : name;

  String localizedDescription(bool isArabic) =>
      (isArabic && descriptionAr != null && descriptionAr!.isNotEmpty)
      ? descriptionAr!
      : description;

  int get totalSubjectsCount =>
      levels.fold(0, (sum, level) => sum + level.subjects.length);
}
