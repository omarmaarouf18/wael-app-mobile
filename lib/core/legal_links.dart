import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import 'external_links.dart';

/// Legal page URLs with always-working fallbacks (owner decision 2026-10-08).
///
/// The server may point the terms/privacy pages elsewhere through
/// `GET /academy/app-config`; when its value is missing or not a valid
/// `https` URL, the bundled fallback constants below are used instead, so
/// the links never disappear (empty config and offline included).
/// English UI appends `#en`: the pages switch language on that hash.

/// Fallback legal pages (also the app-config defaults on a fresh server).
const legalTermsFallbackUrl = 'https://legal.elmetracademy.app/terms';
const legalPrivacyFallbackUrl = 'https://legal.elmetracademy.app/privacy';
const legalDeleteAccountFallbackUrl =
    'https://legal.elmetracademy.app/delete-account';

/// Keeps [configured] when it is a valid `https` URL, else empty.
String _validHttps(String configured) {
  final raw = configured.trim();
  if (raw.isEmpty) return '';
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return '';
  return raw;
}

/// Terms page: the app-config value when it is a valid `https` URL, else
/// the fallback. Never empty.
String legalTermsUrl(String configured) {
  final picked = _validHttps(configured);
  return picked.isEmpty ? legalTermsFallbackUrl : picked;
}

/// Privacy page: the app-config value when it is a valid `https` URL, else
/// the fallback. Never empty.
String legalPrivacyUrl(String configured) {
  final picked = _validHttps(configured);
  return picked.isEmpty ? legalPrivacyFallbackUrl : picked;
}

/// How-to-delete page. No app-config field exists for it, so this is
/// always the fallback. Never empty.
String legalDeleteAccountUrl() => legalDeleteAccountFallbackUrl;

/// Appends `#en` for English UI (the pages switch language on that hash),
/// unless the URL already carries a fragment.
String withUiLanguage(String url, {required bool isArabic}) {
  if (isArabic || url.contains('#')) return url;
  return '$url#en';
}

/// Opens a legal [url] in the external browser. Only `https` URLs are ever
/// opened; anything else returns false without launching.
Future<bool> openLegalPage(
  String url, {
  LaunchUrl launch = defaultLaunchUrl,
}) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
  return launch(uri, mode: LaunchMode.externalApplication);
}
