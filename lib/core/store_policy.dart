import 'package:flutter/foundation.dart';

/// Store rules that depend on the running platform. They are decided in the
/// app by platform, never by a server flag, so a store reviewer always sees
/// the same build behaviour.
class StorePolicy {
  StorePolicy._();

  /// The phone is optional at signup only in the iOS app (owner amendment
  /// 2026-11-12, App Store 5.1.1(v)); Android and the website require it.
  static bool phoneOptionalAtSignup([TargetPlatform? platform]) =>
      !kIsWeb && (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;

  /// The `X-Client` header value for this app: `ios` or `android`, or null
  /// elsewhere (the website sends its own `web`). The server reads it at
  /// signup to decide whether the phone may be left out.
  static String? clientId([TargetPlatform? platform]) {
    if (kIsWeb) return null;
    switch (platform ?? defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return null;
    }
  }
}
