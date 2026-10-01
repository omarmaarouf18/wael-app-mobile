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

  test('other platforms do nothing and never touch the channel', () async {
    handler((call) async => null);
    for (final platform in [
      TargetPlatform.iOS,
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
}
