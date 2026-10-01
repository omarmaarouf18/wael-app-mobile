import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Raised when the screen cannot be made secure on a platform that supports
/// it. The player treats this as "do not play" (fail closed).
class SecureScreenException implements Exception {
  SecureScreenException(this.message);

  final String message;

  @override
  String toString() => 'SecureScreenException: $message';
}

/// Android `FLAG_SECURE` for the current window, through a small method
/// channel implemented in `MainActivity.kt` (no extra package).
///
/// While it is on, screenshots, screen recording and the recent-apps
/// thumbnail show nothing. Turn it on only for the protected player screen
/// and off again when that screen closes.
///
/// Android is the only supported platform for now (the owner's decision);
/// on others [isSupported] is false and both calls do nothing.
class SecureScreen {
  SecureScreen({MethodChannel? channel, this.platform})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.wael.app/secure_screen';

  final MethodChannel _channel;

  /// Overrides the detected platform (tests).
  final TargetPlatform? platform;

  bool get isSupported =>
      !kIsWeb && (platform ?? defaultTargetPlatform) == TargetPlatform.android;

  /// Sets FLAG_SECURE. Throws [SecureScreenException] if the platform supports
  /// it but the call fails.
  Future<void> enable() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('enable');
    } on PlatformException catch (e) {
      throw SecureScreenException(e.code);
    } on MissingPluginException {
      throw SecureScreenException('channel not implemented');
    }
  }

  /// Clears FLAG_SECURE. A failure leaves the stricter state in place, so it
  /// is not reported.
  Future<void> disable() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('disable');
    } on PlatformException {
      // ignored on purpose
    } on MissingPluginException {
      // ignored on purpose
    }
  }

  /// Whether the window currently has FLAG_SECURE (false when unsupported).
  Future<bool> isEnabled() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
