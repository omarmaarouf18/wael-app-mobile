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

/// Represents a parsed semantic app version with dotted segments and an
/// optional numeric build number (e.g. `1.2.3+4`).
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.segments, [this.build = 0]);

  final List<int> segments;
  final int build;

  @override
  int compareTo(AppVersion other) {
    final maxLen = segments.length > other.segments.length
        ? segments.length
        : other.segments.length;
    for (var i = 0; i < maxLen; i++) {
      final sa = i < segments.length ? segments[i] : 0;
      final sb = i < other.segments.length ? other.segments[i] : 0;
      if (sa != sb) return sa.compareTo(sb);
    }
    return build.compareTo(other.build);
  }
}

/// Parses a semver-style version string tolerant of `"1.2"`, `"1.2.3"`, and
/// build suffix `"+4"`. Returns null for invalid or empty strings.
AppVersion? parseAppVersion(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('v') || s.startsWith('V')) {
    s = s.substring(1).trim();
  }
  if (s.isEmpty) return null;

  int build = 0;
  if (s.contains('+')) {
    final plusParts = s.split('+');
    s = plusParts.first.trim();
    final buildPart = plusParts.length > 1 ? plusParts[1].trim() : '';
    if (buildPart.isNotEmpty) {
      final b = int.tryParse(buildPart);
      if (b == null || b < 0) return null;
      build = b;
    }
  } else if (s.contains('-')) {
    s = s.split('-').first.trim();
  }

  if (s.isEmpty) return null;
  final segs = s.split('.');
  final numbers = <int>[];
  for (final seg in segs) {
    final trimmed = seg.trim();
    if (trimmed.isEmpty) return null;
    final n = int.tryParse(trimmed);
    if (n == null || n < 0) return null;
    numbers.add(n);
  }
  if (numbers.isEmpty) return null;
  return AppVersion(numbers, build);
}

/// Returns true if [version] is a valid semver-style version string.
bool isValidAppVersion(String version) => parseAppVersion(version) != null;

/// Compares semver-style version strings. Tolerant of "1.2", "1.2.3", and
/// build suffix "+4". Returns negative/zero/positive like [Comparable.compareTo].
/// Invalid or empty versions compare as lower than valid ones.
int compareAppVersions(String a, String b) {
  final va = parseAppVersion(a);
  final vb = parseAppVersion(b);
  if (va == null && vb == null) return 0;
  if (va == null) return -1;
  if (vb == null) return 1;
  return va.compareTo(vb);
}
