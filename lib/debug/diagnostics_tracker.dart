import 'package:flutter/foundation.dart';
import '../core/app_config.dart';
import '../providers/auth_provider.dart';

/// Metadata for a recorded API call.
/// Never stores request or response bodies, tokens, or query strings.
class ApiCallRecord {
  ApiCallRecord({
    required this.timestamp,
    required this.method,
    required String rawPath,
    required this.status,
    required this.latencyMs,
  }) : path = _stripQuery(rawPath);

  final DateTime timestamp;
  final String method;
  final String path;
  final int status;
  final int latencyMs;

  static String _stripQuery(String raw) {
    final idx = raw.indexOf('?');
    return idx != -1 ? raw.substring(0, idx) : raw;
  }
}

/// Central tracker for in-app diagnostics. Active and accessible only in debug mode.
class DiagnosticsTracker extends ChangeNotifier {
  DiagnosticsTracker._();

  static final DiagnosticsTracker instance = DiagnosticsTracker._();

  final List<ApiCallRecord> _calls = [];
  String _sseState = 'disconnected';

  List<ApiCallRecord> get calls => List.unmodifiable(_calls);
  String get sseState => _sseState;
  String get baseUrl => AppConfig.baseUrl;

  void updateSseState(String state) {
    _sseState = state;
    notifyListeners();
  }

  /// Records an API call into the circular buffer (last 50 calls).
  /// Strips any query strings and avoids storing sensitive payloads.
  void recordCall({
    required String method,
    required String path,
    required int status,
    required int latencyMs,
  }) {
    final record = ApiCallRecord(
      timestamp: DateTime.now(),
      method: method.toUpperCase(),
      rawPath: path,
      status: status,
      latencyMs: latencyMs,
    );
    _calls.insert(0, record);
    if (_calls.length > 50) {
      _calls.removeLast();
    }
    notifyListeners();
  }

  /// Formats the session state for debug observation with sensitive data masked.
  String maskedSessionState(AuthProvider? auth) {
    if (auth == null) return 'No auth provider';
    final status = auth.status.name;
    final email = auth.account?.email ?? auth.currentUser.email;
    final emailDisplay = email.isNotEmpty ? email : 'none';
    return 'Status: $status | User: $emailDisplay';
  }

  /// Masks a token to first 6 characters followed by '...'
  static String maskToken(String? token) {
    if (token == null || token.isEmpty) return 'none';
    if (token.length <= 6) return '***';
    return '${token.substring(0, 6)}...';
  }

  void clear() {
    _calls.clear();
    _sseState = 'disconnected';
    notifyListeners();
  }
}
