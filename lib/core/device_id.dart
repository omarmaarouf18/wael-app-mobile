import 'dart:math';
import 'secure_store.dart';

/// Helper for retrieving or generating the stable RFC 4122 UUIDv4 device_id.
/// Stored in [TokenStore], never regenerated unless app storage is wiped.
class DeviceIdManager {
  DeviceIdManager._();

  /// Generates a random RFC 4122 compliant UUIDv4 string.
  /// Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx (where y is 8, 9, a, or b).
  static String generateUuidV4([Random? random]) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

    // Set version to 4 (bits 4-7 of byte 6 to 0100)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant to RFC 4122 (bits 6-7 of byte 8 to 10)
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Gets the existing device_id from [store] or generates and persists a new one.
  static Future<String> getOrCreateDeviceId(
    TokenStore store, [
    Random? random,
  ]) async {
    final existing = await store.readDeviceId();
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    final newId = generateUuidV4(random);
    await store.writeDeviceId(newId);
    return newId;
  }
}
