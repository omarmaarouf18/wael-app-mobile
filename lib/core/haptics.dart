import 'package:flutter/services.dart';

/// Light haptics for exactly three moments: successful login, a sent access
/// request, and a notification tap. Nothing else vibrates.
///
/// Every call is fire-and-forget and never throws: on devices without a
/// vibrator, in widget/unit tests without a platform channel, or when the
/// binding is absent, the request is silently dropped.
class AppHaptics {
  AppHaptics._();

  static void light() {
    try {
      HapticFeedback.lightImpact().then<void>((_) {}, onError: (_) {});
    } catch (_) {
      // No binding, no channel, or no vibrator: haptics are best-effort.
    }
  }
}
