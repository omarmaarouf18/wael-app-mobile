import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:url_launcher/url_launcher.dart';

/// Opens external links (support WhatsApp chat for help and access requests).
///
/// Only `https://wa.me/…` links are ever opened: the model already keeps
/// https-only URLs, and [whatsappUrl] additionally requires the `wa.me`
/// host, so a stray link can never send the student elsewhere.
typedef LaunchUrl = Future<bool> Function(Uri url, {LaunchMode mode});

Future<bool> defaultLaunchUrl(
  Uri url, {
  LaunchMode mode = LaunchMode.externalApplication,
}) => launchUrl(url, mode: mode);

/// One guard for every external launch (WhatsApp, update, legal pages;
/// 2026-10-12): a second tap on the same link while its launch is in flight,
/// or within [cooldown] after it, is ignored, so a double tap opens the link
/// once. Different links are independent (Terms then Privacy both open).
class LaunchGuard {
  LaunchGuard({this.cooldown = const Duration(seconds: 1)});

  /// The app-wide instance every launch helper uses.
  static final instance = LaunchGuard();

  final Duration cooldown;

  /// Time source for the cooldown. Tests replace it.
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  final Set<String> _inFlight = {};
  final Map<String, DateTime> _done = {};

  /// Runs [launch] for [key] unless that key is in flight or cooling down;
  /// an ignored tap answers true (the first tap is already handling it).
  Future<bool> run(String key, Future<bool> Function() launch) async {
    if (_inFlight.contains(key)) return true;
    final last = _done[key];
    if (last != null && clock().difference(last) < cooldown) return true;
    _inFlight.add(key);
    try {
      return await launch();
    } finally {
      _inFlight.remove(key);
      _done[key] = clock();
    }
  }

  /// Forgets every launch (tests).
  @visibleForTesting
  void reset() {
    _inFlight.clear();
    _done.clear();
    clock = DateTime.now;
  }
}

/// [launch] for [uri] behind [LaunchGuard.instance], keyed by the link.
Future<bool> guardedLaunch(
  Uri uri,
  LaunchUrl launch, {
  LaunchMode mode = LaunchMode.externalApplication,
}) => LaunchGuard.instance.run(uri.toString(), () => launch(uri, mode: mode));

/// Builds the WhatsApp URL with a prefilled, URL-encoded [messageText]
/// (`Uri` encodes the `text` parameter), or null when [supportUrl] is not
/// an `https://wa.me/…` link. The caller shows only the copy action then.
Uri? whatsappUrl({required String? supportUrl, required String messageText}) {
  final raw = (supportUrl ?? '').trim();
  if (raw.isEmpty) return null;
  final base = Uri.tryParse(raw);
  if (base == null || base.scheme != 'https' || base.host != 'wa.me') {
    return null;
  }
  return base.replace(queryParameters: {'text': messageText});
}

/// Opens the support WhatsApp chat in the external app, falling back to the
/// browser when WhatsApp is missing. Returns false when there is nothing to
/// open (non-wa.me URL) or both attempts fail.
Future<bool> openSupportChat({
  required String? supportUrl,
  required String messageText,
  LaunchUrl launch = defaultLaunchUrl,
}) async {
  final uri = whatsappUrl(supportUrl: supportUrl, messageText: messageText);
  if (uri == null) return false;
  // The app attempt and its browser fallback are one guarded launch.
  return LaunchGuard.instance.run(uri.toString(), () => _openChat(uri, launch));
}

Future<bool> _openChat(Uri uri, LaunchUrl launch) async {
  try {
    if (await launch(uri, mode: LaunchMode.externalApplication)) return true;
  } catch (_) {
    // External app launch failed or threw; fall back to browser.
  }
  try {
    return await launch(uri, mode: LaunchMode.platformDefault);
  } catch (_) {
    return false;
  }
}
