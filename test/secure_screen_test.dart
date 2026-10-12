import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/services/secure_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <String>[];
  late MethodChannel channel;

  void handler(Future<Object?>? Function(MethodCall call) fn) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call.method);
          return fn(call);
        });
  }

  setUp(() {
    calls.clear();
    channel = const MethodChannel(SecureScreen.channelName);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('the channel name matches MainActivity.kt', () {
    expect(SecureScreen.channelName, 'com.wael.app/secure_screen');
  });

  test('enable and disable call the channel on Android', () async {
    var flag = false;
    handler((call) async {
      if (call.method == 'enable') flag = true;
      if (call.method == 'disable') flag = false;
      if (call.method == 'isEnabled') return flag;
      return null;
    });
    final secure = SecureScreen(platform: TargetPlatform.android);

    expect(secure.isSupported, isTrue);
    expect(await secure.isEnabled(), isFalse);
    await secure.enable();
    expect(await secure.isEnabled(), isTrue);
    await secure.disable();
    expect(await secure.isEnabled(), isFalse);
    expect(calls, ['isEnabled', 'enable', 'isEnabled', 'disable', 'isEnabled']);
  });

  // Amended 2026-10-12 (owner decision: recording protection covers iOS
  // too): iOS left this list; it now uses the channel for capture detection
  // (tests below and test/ios_capture_cover_test.dart).
  test('other platforms do nothing and never touch the channel', () async {
    handler((call) async => null);
    for (final platform in [
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      final secure = SecureScreen(platform: platform);
      expect(secure.isSupported, isFalse);
      await secure.enable();
      await secure.disable();
      expect(await secure.isEnabled(), isFalse);
    }
    expect(calls, isEmpty);
  });

  test('enable fails closed when the Android call fails', () async {
    handler((call) async => throw PlatformException(code: 'boom'));
    final secure = SecureScreen(platform: TargetPlatform.android);
    await expectLater(secure.enable(), throwsA(isA<SecureScreenException>()));
  });

  test('enable fails closed when the channel is missing', () async {
    // No handler registered: invokeMethod throws MissingPluginException.
    final secure = SecureScreen(platform: TargetPlatform.android);
    await expectLater(secure.enable(), throwsA(isA<SecureScreenException>()));
  });

  test('disable never throws', () async {
    handler((call) async => throw PlatformException(code: 'boom'));
    final secure = SecureScreen(platform: TargetPlatform.android);
    await secure.disable();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await secure.disable();
  });

  test('the capture channel name matches AppDelegate.swift', () {
    expect(
      SecureScreen.captureChannelName,
      'com.wael.app/secure_screen/capture',
    );
  });

  test(
    'iOS: enable proves the channel, FLAG_SECURE stays Android-only',
    () async {
      handler((call) async => call.method == 'isCaptured' ? false : null);
      final secure = SecureScreen(platform: TargetPlatform.iOS);
      expect(secure.isSupported, isFalse);
      expect(secure.detectsCapture, isTrue);
      await secure.enable();
      expect(await secure.isCaptured(), isFalse);
      await secure.disable();
      expect(calls, ['enable', 'isCaptured']);
    },
  );

  test('iOS: isCaptured fails closed', () async {
    final secure = SecureScreen(platform: TargetPlatform.iOS);
    // Missing channel.
    await expectLater(secure.enable(), throwsA(isA<SecureScreenException>()));
    await expectLater(
      secure.isCaptured(),
      throwsA(isA<SecureScreenException>()),
    );
    // Error and non-bool answers.
    handler((call) async => throw PlatformException(code: 'boom'));
    await expectLater(
      secure.isCaptured(),
      throwsA(isA<SecureScreenException>()),
    );
    handler((call) async => 'yes');
    await expectLater(
      secure.isCaptured(),
      throwsA(isA<SecureScreenException>()),
    );
  });
}
