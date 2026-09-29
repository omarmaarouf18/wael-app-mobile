class InstructorProfile {
  final String id;
  final String name;
  final String? nameAr;
  final String title;
  final String? titleAr;
  final String bio;
  final String? bioAr;
  final String imagePath;
  final List<String> credentials;
  final List<String>? credentialsAr;

  const InstructorProfile({
    required this.id,
    required this.name,
    this.nameAr,
    required this.title,
    this.titleAr,
    required this.bio,
    this.bioAr,
    required this.imagePath,
    this.credentials = const [],
    this.credentialsAr,
  });

  String localizedName(bool isArabic) =>
      (isArabic && nameAr != null && nameAr!.isNotEmpty) ? nameAr! : name;

  String localizedTitle(bool isArabic) =>
      (isArabic && titleAr != null && titleAr!.isNotEmpty) ? titleAr! : title;

  String localizedBio(bool isArabic) =>
      (isArabic && bioAr != null && bioAr!.isNotEmpty) ? bioAr! : bio;

  List<String> localizedCredentials(bool isArabic) =>
      (isArabic && credentialsAr != null && credentialsAr!.isNotEmpty)
      ? credentialsAr!
      : credentials;
}
