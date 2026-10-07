import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' show IOClient;
import '../debug/diagnostics_tracker.dart';

/// Outcome of a token refresh attempt, so a transient failure (network,
/// timeout, 5xx, 408, 429) never ends the session while a definitive one
/// (rejected refresh, missing token) still does.
enum RefreshOutcome { success, transientFailure, permanentFailure }

/// Real HTTP client for the wael-app gateway.
///
/// - Base URL is injected (see [AppConfig]); nothing is hardcoded.
/// - JWT is injected per request via [accessTokenReader].
/// - On 401 the client runs the refresh once and retries; if refresh fails
///   definitively (or none is configured) it runs [forceLogout]. A transient
///   refresh failure ([RefreshOutcome.transientFailure]) never triggers
///   [forceLogout]: the original 401 surfaces and the caller keeps its
///   tokens. The second-401 depth-limit path always triggers [forceLogout].
/// - 429 responses surface as [ApiException] with the backend message so the
///   UI can show a clear rate-limit/lockout notice.
/// - Every request has a timeout ([timeout], [playTimeout] for `/play`):
///   expiry surfaces as `ApiException(statusCode: -1, code: 'timeout')`,
///   which the UI reads as a retryable network error. SSE keeps its own
///   reconnect logic and is not timed out here.
/// - Self-signed gateway certificates are accepted in debug builds only
///   ([allowSelfSigned]); release builds always verify.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.accessTokenReader,
    this.refreshTokens,
    this.refreshWithOutcome,
    this.forceLogout,
    this.localeReader,
    this.onSessionReplaced,
    this.allowSelfSigned = false,
    this.timeout = defaultTimeout,
    this.playTimeout = defaultPlayTimeout,
  }) : _client = client ?? _defaultClient(allowSelfSigned);

  /// Default per-request budget; the video play call gets longer.
  static const defaultTimeout = Duration(seconds: 15);
  static const defaultPlayTimeout = Duration(seconds: 30);

  final String baseUrl;
  final http.Client _client;
  final Future<String?> Function()? accessTokenReader;
  final Future<bool> Function()? refreshTokens;

  /// Distinguishing refresh callback (preferred over [refreshTokens] when
  /// both are set): `success` retries, `permanentFailure` triggers
  /// [forceLogout], `transientFailure` surfaces the 401 with no logout.
  /// Legacy [refreshTokens] (`false`) keeps the old behaviour (logout) for
  /// existing callers and tests.
  final Future<RefreshOutcome> Function()? refreshWithOutcome;
  final Future<void> Function()? forceLogout;
  final String? Function()? localeReader;
  final Future<void> Function(String? message)? onSessionReplaced;
  final bool allowSelfSigned;

  /// Per-request budgets (overridable in tests so they stay fast).
  final Duration timeout;
  final Duration playTimeout;

  /// `/play` (video start) gets the longer budget; everything else the
  /// default. Only the academy play endpoint ends in `/play`.
  Duration _timeoutFor(String path) =>
      path.endsWith('/play') ? playTimeout : timeout;

  /// A timed-out request reads as a retryable client-side failure.
  ApiException _timedOut() => ApiException(
    statusCode: -1,
    message: 'Request timed out',
    code: 'timeout',
  );

  Future<bool>? _refreshInFlight;
  Future<RefreshOutcome>? _refreshOutcomeInFlight;

  static http.Client _defaultClient(bool allowSelfSigned) {
    if (allowSelfSigned && kDebugMode) {
      final io = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;
      return IOClient(io);
    }
    return http.Client();
  }

  Map<String, String> _headers(String? token) {
    final lang = localeReader?.call();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (lang != null && lang.isNotEmpty) 'Accept-Language': lang,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<String?> _token() => accessTokenReader?.call() ?? Future.value(null);

  void _record(String method, String path, int statusCode, int ms) {
    if (kDebugMode) {
      DiagnosticsTracker.instance.recordCall(
        method: method,
        path: path,
        status: statusCode,
        latencyMs: ms,
      );
    }
  }

  Future<Map<String, dynamic>> get(String path, {bool isRetry = false}) async {
    final sw = Stopwatch()..start();
    int statusCode = -1;
    try {
      final token = await _token();
      final res = await _client
          .get(Uri.parse('$baseUrl$path'), headers: _headers(token))
          .timeout(_timeoutFor(path));
      statusCode = res.statusCode;
      return await _handle(
        res,
        () => get(path, isRetry: true),
        isRetry: isRetry,
      );
    } on TimeoutException {
      throw _timedOut();
    } catch (e) {
      if (e is ApiException) statusCode = e.statusCode;
      rethrow;
    } finally {
      sw.stop();
      _record('GET', path, statusCode, sw.elapsedMilliseconds);
    }
  }

  /// Single authenticated GET with an explicit token (no refresh dance).
  Future<Map<String, dynamic>> getAuthed(String path, String token) async {
    final sw = Stopwatch()..start();
    int statusCode = -1;
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl$path'), headers: _headers(token))
          .timeout(_timeoutFor(path));
      statusCode = res.statusCode;
      return _decode(res);
    } on TimeoutException {
      throw _timedOut();
    } catch (e) {
      if (e is ApiException) statusCode = e.statusCode;
      rethrow;
    } finally {
      sw.stop();
      _record('GET', path, statusCode, sw.elapsedMilliseconds);
    }
  }

  /// Single authenticated POST with an explicit token (no refresh dance).
  Future<Map<String, dynamic>> postAuthed(
    String path,
    String token, {
    Map<String, dynamic>? body,
  }) async {
    final sw = Stopwatch()..start();
    int statusCode = -1;
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers(token),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(_timeoutFor(path));
      statusCode = res.statusCode;
      return _decode(res);
    } on TimeoutException {
      throw _timedOut();
    } catch (e) {
      if (e is ApiException) statusCode = e.statusCode;
      rethrow;
    } finally {
      sw.stop();
      _record('POST', path, statusCode, sw.elapsedMilliseconds);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool isRetry = false,
  }) async {
    final sw = Stopwatch()..start();
    int statusCode = -1;
    try {
      final token = await _token();
      final res = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers(token),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(_timeoutFor(path));
      statusCode = res.statusCode;
      return await _handle(
        res,
        () => post(path, body: body, isRetry: true),
        isRetry: isRetry,
      );
    } on TimeoutException {
      throw _timedOut();
    } catch (e) {
      if (e is ApiException) statusCode = e.statusCode;
      rethrow;
    } finally {
      sw.stop();
      _record('POST', path, statusCode, sw.elapsedMilliseconds);
    }
  }

  /// Authenticated PATCH with the refresh dance (account profile edits).
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool isRetry = false,
  }) async {
    final sw = Stopwatch()..start();
    int statusCode = -1;
    try {
      final token = await _token();
      final res = await _client
          .patch(
            Uri.parse('$baseUrl$path'),
            headers: _headers(token),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(_timeoutFor(path));
      statusCode = res.statusCode;
      return await _handle(
        res,
        () => patch(path, body: body, isRetry: true),
        isRetry: isRetry,
      );
    } on TimeoutException {
      throw _timedOut();
    } catch (e) {
      if (e is ApiException) statusCode = e.statusCode;
      rethrow;
    } finally {
      sw.stop();
      _record('PATCH', path, statusCode, sw.elapsedMilliseconds);
    }
  }

  /// Authenticated DELETE with the refresh dance (ending a device session).
  /// A 204 answers the empty map.
  Future<Map<String, dynamic>> delete(
    String path, {
    bool isRetry = false,
  }) async {
    final sw = Stopwatch()..start();
    int statusCode = -1;
    try {
      final token = await _token();
      final res = await _client
          .delete(Uri.parse('$baseUrl$path'), headers: _headers(token))
          .timeout(_timeoutFor(path));
      statusCode = res.statusCode;
      return await _handle(
        res,
        () => delete(path, isRetry: true),
        isRetry: isRetry,
      );
    } on TimeoutException {
      throw _timedOut();
    } catch (e) {
      if (e is ApiException) statusCode = e.statusCode;
      rethrow;
    } finally {
      sw.stop();
      _record('DELETE', path, statusCode, sw.elapsedMilliseconds);
    }
  }

  Future<Map<String, dynamic>> _handle(
    http.Response res,
    Future<Map<String, dynamic>> Function() retry, {
    bool isRetry = false,
  }) async {
    if (res.statusCode == 401) {
      final body = _tryDecodeMap(res.body);
      if (body != null && body['code'] == 'session_replaced') {
        final msg = body['error']?.toString();
        await onSessionReplaced?.call(msg);
        return _decode(res);
      }
      if (isRetry) {
        // Retry depth limit reached: a second 401 goes to forced-logout.
        if (_claimLogout()) await forceLogout?.call();
      } else if (refreshWithOutcome != null) {
        final outcome = await _refreshOnceWithOutcome();
        if (outcome == RefreshOutcome.success) return retry();
        if (outcome == RefreshOutcome.permanentFailure) {
          // Definitive refresh failure: exactly one caller of this round
          // reports the logout, the rest just surface the 401.
          if (_claimLogout()) await forceLogout?.call();
        }
        // Transient failure: no logout; the original 401 surfaces below.
      } else if (refreshTokens != null) {
        final ok = await _refreshOnce();
        if (ok) return retry();
        // The refresh failed: exactly one caller of this round reports
        // the logout, the rest just surface the 401.
        if (_claimLogout()) await forceLogout?.call();
      } else {
        await forceLogout?.call();
      }
    }
    return _decode(res);
  }

  Map<String, dynamic>? _tryDecodeMap(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// True once a caller claimed the logout for the current failed refresh
  /// round. Reset whenever a new refresh starts, so every failed refresh
  /// logs out at most once no matter how many callers waited on it.
  bool _logoutClaimed = false;

  /// Runs [forceLogout] at most once per failed refresh: the first caller
  /// of a failed round claims it, later callers of the same round skip it.
  /// Single-threaded claim check, so exactly one caller wins.
  bool _claimLogout() {
    if (_logoutClaimed) return false;
    _logoutClaimed = true;
    return true;
  }

  /// Shares one in-flight refresh between concurrent 401s. Waiters receive
  /// the real result (a throwing refresh reads as false), never a blanket
  /// `true`, so they do not retry on a dead refresh and re-drive logout.
  Future<bool> _refreshOnce() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    _logoutClaimed = false;
    final future = refreshTokens!.call().then<bool>(
      (ok) => ok,
      onError: (_) => false,
    );
    _refreshInFlight = future;
    return future.whenComplete(() {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    });
  }

  /// Outcome-sharing twin of [_refreshOnce] for [refreshWithOutcome]. A
  /// throwing refresh reads as transient (no logout), never as permanent,
  /// so an unexpected callback error cannot end the session.
  Future<RefreshOutcome> _refreshOnceWithOutcome() {
    final inFlight = _refreshOutcomeInFlight;
    if (inFlight != null) return inFlight;
    _logoutClaimed = false;
    final future = refreshWithOutcome!.call().then<RefreshOutcome>(
      (outcome) => outcome,
      onError: (_) => RefreshOutcome.transientFailure,
    );
    _refreshOutcomeInFlight = future;
    return future.whenComplete(() {
      if (identical(_refreshOutcomeInFlight, future)) {
        _refreshOutcomeInFlight = null;
      }
    });
  }

  Map<String, dynamic> _decode(http.Response res) {
    dynamic body;
    try {
      body = res.body.isEmpty ? {} : jsonDecode(res.body);
    } catch (_) {
      body = {};
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body is Map<String, dynamic> ? body : {'data': body};
    }
    final map = body is Map ? body : {};
    int? retryAfter;
    final rawRetry = res.headers['retry-after'] ?? res.headers['Retry-After'];
    if (rawRetry != null) {
      retryAfter = int.tryParse(rawRetry.trim());
    }
    throw ApiException(
      statusCode: res.statusCode,
      message: (map['error'] ?? 'Request failed').toString(),
      code: map['code']?.toString(),
      retryAfterSeconds: retryAfter,
    );
  }

  /// Opens a server-sent-events stream. Each `data:` line carrying a JSON
  /// object is yielded as a decoded map. The caller cancels the subscription
  /// on logout.
  Stream<Map<String, dynamic>> sse(String path, {String? token}) async* {
    if (kDebugMode) {
      DiagnosticsTracker.instance.updateSseState('connecting');
    }
    final req = http.Request('GET', Uri.parse('$baseUrl$path'));
    req.headers.addAll(_headers(token));
    req.headers['Accept'] = 'text/event-stream';
    http.StreamedResponse streamed;
    try {
      streamed = await _client.send(req);
    } catch (e) {
      if (kDebugMode) {
        DiagnosticsTracker.instance.updateSseState('error');
      }
      throw ApiException(statusCode: -1, message: 'Stream unavailable: $e');
    }
    if (streamed.statusCode != 200) {
      if (kDebugMode) {
        DiagnosticsTracker.instance.updateSseState(
          'error: ${streamed.statusCode}',
        );
      }
      throw ApiException(
        statusCode: streamed.statusCode,
        message: 'Stream unavailable',
      );
    }
    if (kDebugMode) {
      DiagnosticsTracker.instance.updateSseState('connected');
    }
    try {
      var buffer = '';
      await for (final chunk in streamed.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();
        for (final line in lines) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('data:')) continue;
          final payload = trimmed.substring(5).trim();
          if (payload.isEmpty || payload == '[DONE]') continue;
          try {
            final decoded = jsonDecode(payload);
            if (decoded is Map<String, dynamic>) yield decoded;
          } catch (_) {
            // Skip malformed frames; the stream stays open.
          }
        }
      }
    } finally {
      if (kDebugMode) {
        DiagnosticsTracker.instance.updateSseState('disconnected');
      }
    }
  }

  void dispose() => _client.close();
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final int? retryAfterSeconds;

  ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.retryAfterSeconds,
  });

  bool get isRateLimited => statusCode == 429;
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException: [$statusCode] $message';
}
