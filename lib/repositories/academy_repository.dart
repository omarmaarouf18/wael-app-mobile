import '../core/api_client.dart';
import '../models/academy_catalog.dart';

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
}
