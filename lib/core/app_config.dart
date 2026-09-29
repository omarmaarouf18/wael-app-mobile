import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

/// Backend base URL resolution.
///
/// Override with:
///   flutter run --dart-define=API_BASE_URL=https://host:port
///
/// Per-platform defaults (local compose, default ports):
/// - Android emulator: `https://10.0.2.2:8080` (host loopback alias)
/// - iOS simulator:    `https://localhost:8080`
/// - Desktop/web:      `https://localhost:8080`
/// - Physical device:  `https://LAN-IP:8080` (same network as the host)
///
/// No URL is hardcoded into widgets or providers; everything reads [baseUrl].
class AppConfig {
  AppConfig._();

  static const String _defineKey = 'API_BASE_URL';

  static String get baseUrl {
    const fromDefine = String.fromEnvironment(_defineKey);
    if (fromDefine.isNotEmpty) return _stripTrailingSlash(fromDefine);
    if (kIsWeb) return 'https://localhost:8080';
    try {
      if (Platform.isAndroid) return 'https://10.0.2.2:8080';
    } catch (_) {
      // Platform unavailable in some test contexts; fall through.
    }
    return 'https://localhost:8080';
  }

  /// Local compose uses a self-signed gateway certificate, so debug builds
  /// accept it. Release builds always verify (never set a bad-certificate
  /// callback outside debug).
  static bool get allowSelfSigned => kDebugMode;

  static String _stripTrailingSlash(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
