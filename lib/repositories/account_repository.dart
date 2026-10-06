import '../core/api_client.dart';

/// One of the caller's signed-in devices (`GET /auth/sessions`).
class DeviceSession {
  final String sid;
  final String deviceLabel;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final bool current;

  const DeviceSession({
    required this.sid,
    required this.deviceLabel,
    required this.createdAt,
    required this.lastUsedAt,
    required this.current,
  });

  factory DeviceSession.fromJson(Map<String, dynamic> json) => DeviceSession(
    sid: (json['sid'] ?? '').toString(),
    deviceLabel: (json['device_label'] ?? '').toString(),
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    lastUsedAt:
        DateTime.tryParse(json['last_used_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    current: json['current'] == true,
  );
}

/// Updated identity after `PATCH /auth/me`.
class ProfileUpdate {
  final String fullName;
  final String phone;

  const ProfileUpdate({required this.fullName, required this.phone});

  factory ProfileUpdate.fromJson(Map<String, dynamic> json) => ProfileUpdate(
    fullName: (json['full_name'] ?? '').toString(),
    phone: (json['phone'] ?? '').toString(),
  );
}

/// Self-service account contract (F-UX2 Part A): devices, password, profile,
/// email change and deletion. HTTP binding below; tests use fakes.
/// Sessions end server-side as calls succeed; the caller clears local state.
abstract class AccountRepository {
  /// `GET /auth/sessions`: the caller's active sessions.
  Future<List<DeviceSession>> sessions();

  /// `DELETE /auth/sessions/{sid}`: ends one own session (204). Ending the
  /// current session is logout.
  Future<void> deleteSession(String sid);

  /// `POST /auth/password/change`: ends every other session.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// `PATCH /auth/me`: change name and/or phone with the current password.
  /// At least one of [fullName]/[phone] must be non-empty.
  Future<ProfileUpdate> updateProfile({
    String? fullName,
    String? phone,
    required String currentPassword,
  });

  /// `POST /auth/email/change`: sends the code to the new email. Always
  /// answers success, even when no code is sent.
  Future<void> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  });

  /// `POST /auth/email/confirm`: applies the change and ends all sessions.
  Future<void> confirmEmailChange({required String code});

  /// `POST /auth/account/delete`: requests deletion; answers the purge date.
  Future<String> requestDeletion({
    required String currentPassword,
    String confirm = 'حذف',
  });
}

const _prefix = '/api/v1/auth';

/// HTTP binding of [AccountRepository] against the authed gateway client
/// (refresh dance included, so an expired token does not surface here).
class HttpAccountRepository implements AccountRepository {
  HttpAccountRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<DeviceSession>> sessions() async {
    final res = await _api.get('$_prefix/sessions');
    final raw = res['sessions'];
    if (raw is! List) return [];
    return [
      for (final item in raw)
        if (item is Map<String, dynamic>) DeviceSession.fromJson(item),
    ];
  }

  @override
  Future<void> deleteSession(String sid) async {
    await _api.delete('$_prefix/sessions/${Uri.encodeComponent(sid)}');
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post(
      '$_prefix/password/change',
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }

  @override
  Future<ProfileUpdate> updateProfile({
    String? fullName,
    String? phone,
    required String currentPassword,
  }) async {
    final res = await _api.patch(
      '$_prefix/me',
      body: {
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'current_password': currentPassword,
      },
    );
    return ProfileUpdate.fromJson(res);
  }

  @override
  Future<void> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    await _api.post(
      '$_prefix/email/change',
      body: {'new_email': newEmail, 'current_password': currentPassword},
    );
  }

  @override
  Future<void> confirmEmailChange({required String code}) async {
    await _api.post('$_prefix/email/confirm', body: {'code': code});
  }

  @override
  Future<String> requestDeletion({
    required String currentPassword,
    String confirm = 'حذف',
  }) async {
    final res = await _api.post(
      '$_prefix/account/delete',
      body: {'current_password': currentPassword, 'confirm': confirm},
    );
    return (res['deletion_date'] ?? '').toString();
  }
}
