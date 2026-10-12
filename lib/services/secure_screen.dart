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
/// *(Amended 2026-10-12, owner decision: recording protection covers iOS
/// too. iOS cannot block recording, so it is detected instead: the same
/// method channel, implemented in `AppDelegate.swift`, answers
/// [isCaptured], and the event channel [captureChannelName] sends the
/// capture state on every change ([captureChanges]). The player covers and
/// pauses the video while it is true. On iOS [enable] only proves the
/// channel exists, and fails closed when it does not. The Android
/// FLAG_SECURE path is unchanged; [isSupported] still means FLAG_SECURE.)*
class SecureScreen {
  SecureScreen({
    MethodChannel? channel,
    EventChannel? captureChannel,
    this.platform,
  }) : _channel = channel ?? const MethodChannel(channelName),
       _captureChannel =
           captureChannel ?? const EventChannel(captureChannelName);

  static const channelName = 'com.wael.app/secure_screen';

  /// iOS only: the screen-capture state, a bool now and on every change.
  static const captureChannelName = 'com.wael.app/secure_screen/capture';

  final MethodChannel _channel;
  final EventChannel _captureChannel;

  /// Overrides the detected platform (tests).
  final TargetPlatform? platform;

  /// FLAG_SECURE is available (Android).
  bool get isSupported =>
      !kIsWeb && (platform ?? defaultTargetPlatform) == TargetPlatform.android;

  /// Screen capture is detected instead of blocked (iOS).
  bool get detectsCapture =>
      !kIsWeb && (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;

  /// Sets FLAG_SECURE (Android) or checks that the capture channel exists
  /// (iOS). Throws [SecureScreenException] if the platform supports it but
  /// the call fails.
  Future<void> enable() async {
    if (detectsCapture) {
      try {
        await _channel.invokeMethod<void>('enable');
      } on PlatformException catch (e) {
        throw SecureScreenException(e.code);
      } on MissingPluginException {
        throw SecureScreenException('channel not implemented');
      }
      return;
    }
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

  /// iOS: whether the screen is being recorded, mirrored or captured right
  /// now. Always false where capture is blocked or not handled (Android has
  /// FLAG_SECURE). Fails closed: a missing channel, an error or a non-bool
  /// answer throws [SecureScreenException].
  Future<bool> isCaptured() async {
    if (!detectsCapture) return false;
    final Object? answer;
    try {
      answer = await _channel.invokeMethod<Object?>('isCaptured');
    } on PlatformException catch (e) {
      throw SecureScreenException(e.code);
    } on MissingPluginException {
      throw SecureScreenException('channel not implemented');
    }
    if (answer is! bool) throw SecureScreenException('no capture state');
    return answer;
  }

  /// iOS: the capture state on every change (the native side also sends the
  /// current one on listen). Anything but a real `false` counts as captured
  /// (fail closed); the stream's errors reach the listener, which must treat
  /// them as captured too. Empty on other platforms.
  Stream<bool> captureChanges() {
    if (!detectsCapture) return const Stream<bool>.empty();
    return _captureChannel.receiveBroadcastStream().map((e) => e != false);
  }
}
