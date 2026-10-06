/// Public app configuration served by `GET /academy/app-config` (SPEC
/// Phase 2.2 A7): the support WhatsApp link, the terms/privacy page URLs
/// and the optional update metadata. Empty means absent (no prompt, no
/// tile action); only `https` URLs are ever kept.
class AppConfigData {
  const AppConfigData({
    this.supportWhatsappUrl = '',
    this.termsUrl = '',
    this.privacyUrl = '',
    this.minVersion = '',
    this.latestVersion = '',
    this.updateUrl = '',
  });

  final String supportWhatsappUrl;
  final String termsUrl;
  final String privacyUrl;
  final String minVersion;
  final String latestVersion;
  final String updateUrl;

  /// Parses defensively: the route is public and the JSON may be partial or
  /// malformed after a deploy. Non-https URLs are dropped, never opened.
  factory AppConfigData.fromJson(Map<String, dynamic> json) => AppConfigData(
    supportWhatsappUrl: _httpsUrl(json['support_whatsapp_url']),
    termsUrl: _httpsUrl(json['terms_url']),
    privacyUrl: _httpsUrl(json['privacy_url']),
    minVersion: (json['min_version'] ?? '').toString().trim(),
    latestVersion: (json['latest_version'] ?? '').toString().trim(),
    updateUrl: _httpsUrl(json['update_url']),
  );

  static String _httpsUrl(Object? value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '';
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return '';
    return raw;
  }

  Map<String, dynamic> toJson() => {
    'support_whatsapp_url': supportWhatsappUrl,
    'terms_url': termsUrl,
    'privacy_url': privacyUrl,
    'min_version': minVersion,
    'latest_version': latestVersion,
    'update_url': updateUrl,
  };
}

/// Compares dotted version names numerically (`1.10.0` beats `1.9.0`;
/// non-numeric segments compare as 0). Returns negative/zero/positive like
/// [Comparable.compareTo]. Missing segments count as 0.
int compareAppVersions(String a, String b) {
  final pa = a.split('.');
  final pb = b.split('.');
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final na = i < pa.length ? int.tryParse(pa[i]) ?? 0 : 0;
    final nb = i < pb.length ? int.tryParse(pb[i]) ?? 0 : 0;
    if (na != nb) return na.compareTo(nb);
  }
  return 0;
}
