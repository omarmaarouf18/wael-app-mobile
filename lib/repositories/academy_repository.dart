import '../core/api_client.dart';
import '../models/academy_catalog.dart';
import '../models/app_config.dart';

/// Read access to the academy catalog (academy-service student routes,
/// served by the gateway under `/api/v1/academy/`).
abstract class AcademyRepository {
  /// `GET /academy/levels`: levels with at least one published subject.
  Future<AcademyLevels> levels();

  /// `GET /academy/subjects`: one page of published subjects. [limit] is
  /// capped at 100 by the server.
  Future<SubjectPage> subjects({
    String? levelKey,
    String? term,
    int page = 1,
    int limit = 20,
  });

  /// `GET /academy/subjects/{id}`: throws [ApiException] with status 404 for
  /// unknown or unpublished subjects.
  Future<AcademySubjectDetail> subject(String id);

  /// `POST /academy/videos/{id}/play`: the YouTube id for a video the student
  /// may play. Throws [ApiException] with status 404 when it is not allowed
  /// (the server answers every refusal the same way). The result must not be
  /// stored, cached or logged by the caller.
  Future<VideoPlayback> playVideo(String videoId);

  /// `POST /academy/subjects/{id}/access-request`: idempotent, so a repeat
  /// call returns the existing pending request. Throws [ApiException] with
  /// 404 (unknown or unpublished subject), 409 (already owned, or the
  /// subject's access date has passed; the server does not say which), 429
  /// (write rate limit) or 503.
  Future<AccessRequest> requestAccess(String subjectId);

  /// `GET /academy/app-config`: public app configuration (support link,
  /// terms/privacy URLs, optional update metadata). Public route, no
  /// student JWT needed; callers cache it and fail soft.
  Future<AppConfigData> appConfig();
}

/// [AcademyRepository] over the authed gateway client. A 401 runs the usual
/// refresh-once-then-logout flow inside [ApiClient]; 5xx and network errors
/// surface as exceptions and never touch the session.
class HttpAcademyRepository implements AcademyRepository {
  HttpAcademyRepository(this._api);

  final ApiClient _api;

  static const _base = '/api/v1/academy';

  @override
  Future<AcademyLevels> levels() async {
    final res = await _api.get('$_base/levels');
    return AcademyLevels.fromJson(res);
  }

  @override
  Future<SubjectPage> subjects({
    String? levelKey,
    String? term,
    int page = 1,
    int limit = 20,
  }) async {
    final query = <String, String>{
      if (levelKey != null && levelKey.isNotEmpty) 'level': levelKey,
      if (term != null && term.isNotEmpty) 'term': term,
      'page': '$page',
      'limit': '$limit',
    };
    final qs = query.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}='
              '${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    final res = await _api.get('$_base/subjects?$qs');
    return SubjectPage.fromJson(res);
  }

  @override
  Future<AcademySubjectDetail> subject(String id) async {
    final res = await _api.get('$_base/subjects/${Uri.encodeComponent(id)}');
    return AcademySubjectDetail.fromJson(res);
  }

  @override
  Future<VideoPlayback> playVideo(String videoId) async {
    final res = await _api.post(
      '$_base/videos/${Uri.encodeComponent(videoId)}/play',
    );
    return VideoPlayback.fromJson(res);
  }

  @override
  Future<AccessRequest> requestAccess(String subjectId) async {
    final res = await _api.post(
      '$_base/subjects/${Uri.encodeComponent(subjectId)}/access-request',
    );
    return AccessRequest.fromJson(res);
  }

  @override
  Future<AppConfigData> appConfig() async {
    final res = await _api.get('$_base/app-config');
    return AppConfigData.fromJson(res);
  }
}
