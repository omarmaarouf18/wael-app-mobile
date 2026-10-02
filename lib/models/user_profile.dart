/// The signed-in student's identity, as the auth service knows it
/// (`GET /auth/me`, and the name and phone typed at signup until then).
/// Nothing here is invented: there is no standing, grade, progress or avatar
/// because the backend sends none.
class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String phone;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
  });

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }
}
