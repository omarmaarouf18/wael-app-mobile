import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' show IOClient;

/// Real HTTP client for the wael-app gateway.
///
/// - Base URL is injected (see [AppConfig]); nothing is hardcoded.
/// - JWT is injected per request via [accessTokenReader].
/// - On 401 the client runs [refreshTokens] once and retries; if refresh
///   fails (or none is configured) it runs [forceLogout].
/// - 429 responses surface as [ApiException] with the backend message so the
///   UI can show a clear rate-limit/lockout notice.
/// - Self-signed gateway certificates are accepted in debug builds only
///   ([allowSelfSigned]); release builds always verify.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.accessTokenReader,
    this.refreshTokens,
    this.forceLogout,
    this.allowSelfSigned = false,
  }) : _client = client ?? _defaultClient(allowSelfSigned);

  final String baseUrl;
  final http.Client _client;
  final Future<String?> Function()? accessTokenReader;
  final Future<bool> Function()? refreshTokens;
  final Future<void> Function()? forceLogout;
  final bool allowSelfSigned;

  Future<bool>? _refreshInFlight;

  static http.Client _defaultClient(bool allowSelfSigned) {
    if (allowSelfSigned && kDebugMode) {
      final io = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;
      return IOClient(io);
    }
    return http.Client();
  }

  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Future<String?> _token() => accessTokenReader?.call() ?? Future.value(null);

  Future<Map<String, dynamic>> get(String path) async {
    final token = await _token();
    final res = await _client.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
    );
    return _handle(res, () => get(path));
  }

  /// Single authenticated GET with an explicit token (no refresh dance).
  Future<Map<String, dynamic>> getAuthed(String path, String token) async {
    final res = await _client.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _token();
    final res = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
      body: body == null ? null : jsonEncode(body),
    );
    return _handle(res, () => post(path, body: body));
  }

  Future<Map<String, dynamic>> _handle(
    http.Response res,
    Future<Map<String, dynamic>> Function() retry,
  ) async {
    if (res.statusCode == 401) {
      if (refreshTokens != null) {
        final ok = await _refreshOnce();
        if (ok) return retry();
      }
      await forceLogout?.call();
    }
    return _decode(res);
  }

  Future<bool> _refreshOnce() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight.then((_) => true, onError: (_) => false);
    }
    final future = refreshTokens!.call();
    _refreshInFlight = future;
    return future.then(
      (ok) {
        _refreshInFlight = null;
        return ok;
      },
      onError: (_) {
        _refreshInFlight = null;
        return false;
      },
    );
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
    throw ApiException(
      statusCode: res.statusCode,
      message: (map['error'] ?? 'Request failed').toString(),
      code: map['code']?.toString(),
    );
  }

  /// Opens a server-sent-events stream. Each `data:` line carrying a JSON
  /// object is yielded as a decoded map. The caller cancels the subscription
  /// on logout.
  Stream<Map<String, dynamic>> sse(String path, {String? token}) async* {
    final req = http.Request('GET', Uri.parse('$baseUrl$path'));
    req.headers.addAll(_headers(token));
    req.headers['Accept'] = 'text/event-stream';
    http.StreamedResponse streamed;
    try {
      streamed = await _client.send(req);
    } catch (e) {
      throw ApiException(statusCode: -1, message: 'Stream unavailable: $e');
    }
    if (streamed.statusCode != 200) {
      throw ApiException(
        statusCode: streamed.statusCode,
        message: 'Stream unavailable',
      );
    }
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
  }

  void dispose() => _client.close();
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;

  ApiException({required this.statusCode, required this.message, this.code});

  bool get isRateLimited => statusCode == 429;
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException: [$statusCode] $message';
}
