import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Result of handing a cached PDF to another app.
enum OpenResult {
  /// The system started a PDF app (or its chooser).
  opened,

  /// No installed app can open a PDF: the UI offers Share instead.
  noApp,

  /// The file is missing, outside the cache root, or the call failed.
  failed,
}

/// Opens or shares a cached PDF with the phone's own apps, through a small
/// method channel implemented in `MainActivity.kt` (no extra package):
///
/// - [open]: `ACTION_VIEW` on a `content://` URI from the app's
///   FileProvider, with read permission granted to the receiving app only;
/// - [share]: the system share sheet (`ACTION_SEND`) with the same URI.
///
/// Only files under `<cache>/pdfs` can be exposed (the provider's single
/// path, checked again natively). No storage permission is used. Android is
/// the only supported platform for now (owner decision); elsewhere both
/// calls answer [OpenResult.failed].
class FileOpener {
  FileOpener({MethodChannel? channel, this.platform})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.wael.app/files';

  final MethodChannel _channel;

  /// Overrides the detected platform (tests).
  final TargetPlatform? platform;

  bool get isSupported =>
      !kIsWeb && (platform ?? defaultTargetPlatform) == TargetPlatform.android;

  Future<OpenResult> open(String path) => _call('open', {'path': path});

  Future<OpenResult> share(String path, String title) =>
      _call('share', {'path': path, 'title': title});

  Future<OpenResult> _call(String method, Map<String, String> args) async {
    if (!isSupported) return OpenResult.failed;
    try {
      final answer = await _channel.invokeMethod<String>(method, args);
      return switch (answer) {
        'opened' => OpenResult.opened,
        'no_app' => OpenResult.noApp,
        _ => OpenResult.failed,
      };
    } on PlatformException {
      return OpenResult.failed;
    } on MissingPluginException {
      return OpenResult.failed;
    }
  }
}
