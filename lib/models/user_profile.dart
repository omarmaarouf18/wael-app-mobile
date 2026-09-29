class UserProfile {
  final String id;
  final String dossierId;
  final String fullName;
  final String email;
  final String phone;
  final String specializationTrack;
  final String bio;
  final String standing;
  final double gpa;
  final int enrolledCoursesCount;
  final int hoursLearned;
  final int notesCount;
  final String avatarUrl;
  final bool biometricEnabled;
  final bool twoFactorEnabled;
  final bool remindersEnabled;
  final bool updatesEnabled;
  final String videoQuality;

  const UserProfile({
    required this.id,
    required this.dossierId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.specializationTrack,
    required this.bio,
    this.standing = 'Senior Scholar • Top 3% Class Standing',
    this.gpa = 3.98,
    this.enrolledCoursesCount = 3,
    this.hoursLearned = 42,
    this.notesCount = 18,
    this.avatarUrl = 'assets/images/profile_alexander_vane.jpg',
    this.biometricEnabled = true,
    this.twoFactorEnabled = true,
    this.remindersEnabled = true,
    this.updatesEnabled = true,
    this.videoQuality = '1080p Full HD',
  });

  UserProfile copyWith({
    String? id,
    String? dossierId,
    String? fullName,
    String? email,
    String? phone,
    String? specializationTrack,
    String? bio,
    String? standing,
    double? gpa,
    int? enrolledCoursesCount,
    int? hoursLearned,
    int? notesCount,
    String? avatarUrl,
    bool? biometricEnabled,
    bool? twoFactorEnabled,
    bool? remindersEnabled,
    bool? updatesEnabled,
    String? videoQuality,
  }) {
    return UserProfile(
      id: id ?? this.id,
      dossierId: dossierId ?? this.dossierId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      specializationTrack: specializationTrack ?? this.specializationTrack,
      bio: bio ?? this.bio,
      standing: standing ?? this.standing,
      gpa: gpa ?? this.gpa,
      enrolledCoursesCount: enrolledCoursesCount ?? this.enrolledCoursesCount,
      hoursLearned: hoursLearned ?? this.hoursLearned,
      notesCount: notesCount ?? this.notesCount,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      updatesEnabled: updatesEnabled ?? this.updatesEnabled,
      videoQuality: videoQuality ?? this.videoQuality,
    );
  }
}
