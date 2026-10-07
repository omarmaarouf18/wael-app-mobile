import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Global test bootstrap.
///
/// Stubs the secure-storage plugin channel to throw [MissingPluginException]
/// (the no-plugin environment) so [SecureTokenStore] and [SecureCatalogCache]
/// take their documented memory-fallback path. Without this, an unhandled
/// platform message never completes under `testWidgets`, hanging any test
/// that signs out (token/cache clear awaits the plugin). Returning `null`
/// instead of throwing would be wrong: the fallback is only used on error,
/// so reads would answer `null` and drop fallback values (e.g. `device_id`
/// would not survive `clear()`). Widget tests that need isolation still
/// inject [MemoryTokenStore] and [MemoryCatalogCache] explicitly.
Future<void> testExecutable(Future<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall call) async {
          throw MissingPluginException(
            'No implementation found for method ${call.method} '
            'on channel plugins.it_nomads.com/flutter_secure_storage',
          );
        },
      );
  await testMain();
}
