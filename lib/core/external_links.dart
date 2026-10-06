import 'package:url_launcher/url_launcher.dart';

/// Opens external links (support WhatsApp chat from purchase requests).
///
/// Only `https://wa.me/…` links are ever opened: the model already keeps
/// https-only URLs, and [whatsappUrl] additionally requires the `wa.me`
/// host, so a stray link can never send the student elsewhere.
typedef LaunchUrl = Future<bool> Function(Uri url, {LaunchMode mode});

Future<bool> defaultLaunchUrl(
  Uri url, {
  LaunchMode mode = LaunchMode.externalApplication,
}) => launchUrl(url, mode: mode);

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
