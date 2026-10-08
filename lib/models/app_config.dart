/// Public app configuration served by `GET /academy/app-config` (SPEC
/// Phase 2.2 A7): the support WhatsApp link, the terms/privacy page URLs
/// and the optional update metadata. Empty means absent (no prompt, no
/// tile action); only `https` URLs are ever kept.
///
/// Unknown or malformed fields fail closed: [`showPrices`] is true only
/// when the server sends a real boolean `true`, and [`center`] is null
/// unless the server sends a usable object.
class AppConfigData {
  const AppConfigData({
    this.supportWhatsappUrl = '',
    this.termsUrl = '',
    this.privacyUrl = '',
    this.minVersion = '',
    this.latestVersion = '',
    this.updateUrl = '',
    this.showPrices = false,
    this.center,
    this.filesEnabled = false,
  });

  final String supportWhatsappUrl;
  final String termsUrl;
  final String privacyUrl;
  final String minVersion;
  final String latestVersion;
  final String updateUrl;

  /// Owner amendment 2026-10-08 (F-UX6): subject prices render only when
  /// this is true AND the subject carries a non-null price. Missing,
  /// false, failed or offline config hides every price (fail closed).
  final bool showPrices;

  /// Optional tutoring-center info for Settings > Help. Null when the
  /// server omits it; the Help section then shows nothing extra.
  final CenterInfo? center;

  /// Server flag `features.files` (client contract 2026-10-08, server
  /// pending): notes and books download only when the server sends a real
  /// boolean `true`. Missing, false, malformed, or never-fetched config
  /// keeps the notes tab in its coming-soon state (fail closed).
  final bool filesEnabled;

  /// Parses defensively: the route is public and the JSON may be partial or
  /// malformed after a deploy. Non-https URLs are dropped, never opened.
  factory AppConfigData.fromJson(Map<String, dynamic> json) => AppConfigData(
    supportWhatsappUrl: _httpsUrl(json['support_whatsapp_url']),
    termsUrl: _httpsUrl(json['terms_url']),
    privacyUrl: _httpsUrl(json['privacy_url']),
    minVersion: (json['min_version'] ?? '').toString().trim(),
    latestVersion: (json['latest_version'] ?? '').toString().trim(),
    updateUrl: _httpsUrl(json['update_url']),
    showPrices: json['show_prices'] == true,
    center: CenterInfo.fromJson(json['center']),
    filesEnabled: _feature(json['features'], 'files'),
  );

  /// A feature is on only for a real boolean `true` inside a `features`
  /// object; anything else (missing, string, number, wrong shape) is off.
  static bool _feature(Object? features, String name) =>
      features is Map && features[name] == true;

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
    'show_prices': showPrices,
    'center': center?.toJson(),
    'features': {'files': filesEnabled},
  };
}

/// Tutoring-center info from `GET /academy/app-config` (owner amendment
/// 2026-10-08, F-UX6): name, address, localized working hours and an
/// optional map link, shown in Settings > Help. `name`, `address` and
/// `hours` each arrive either as an `{ar, en}` object (picked by UI
/// language with fallback to the other side) or, for backward
/// compatibility, as a plain string (shown in both languages). The map
/// link keeps the same https-only rule as every other external URL.
class CenterInfo {
  const CenterInfo({
    this.nameAr = '',
    this.nameEn = '',
    this.addressAr = '',
    this.addressEn = '',
    this.hoursAr = '',
    this.hoursEn = '',
    this.mapUrl = '',
  });

  final String nameAr;
  final String nameEn;
  final String addressAr;
  final String addressEn;
  final String hoursAr;
  final String hoursEn;

  /// Map link, kept only when it is a valid `https` URL, else empty.
  final String mapUrl;

  /// True when there is info text worth showing (the map link is
  /// independent: a map-only object still offers "open map").
  bool get hasContent =>
      nameAr.isNotEmpty ||
      nameEn.isNotEmpty ||
      addressAr.isNotEmpty ||
      addressEn.isNotEmpty ||
      hoursAr.isNotEmpty ||
      hoursEn.isNotEmpty;

  /// Picks the UI-language side, falling back to the other language.
  static String _localized(String ar, String en, bool isArabic) {
    if (isArabic) return ar.isNotEmpty ? ar : en;
    return en.isNotEmpty ? en : ar;
  }

  /// Center name in the UI language, falling back to the other side.
  String nameFor(bool isArabic) => _localized(nameAr, nameEn, isArabic);

  /// Center address in the UI language, falling back to the other side.
  String addressFor(bool isArabic) =>
      _localized(addressAr, addressEn, isArabic);

  /// Working hours in the UI language, falling back to the other side.
  String hoursFor(bool isArabic) => _localized(hoursAr, hoursEn, isArabic);

  static String _text(Object? value) => (value ?? '').toString().trim();

  /// Reads either an `{ar, en}` object or a plain string (shown in both
  /// languages); anything else is empty.
  static (String, String) _localizedPair(Object? value) {
    if (value is Map) {
      return (_text(value['ar']), _text(value['en']));
    }
    if (value is! String) return ('', '');
    final plain = value.trim();
    if (plain.isEmpty) return ('', '');
    return (plain, plain);
  }

  /// Null unless [json] is a map (a missing or malformed `center` field
  /// means "show nothing", never a crash).
  static CenterInfo? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final hours = json['hours'];
    final hoursAr = hours is Map ? _text(hours['ar']) : '';
    final hoursEn = hours is Map ? _text(hours['en']) : '';
    final (nameAr, nameEn) = _localizedPair(json['name']);
    final (addressAr, addressEn) = _localizedPair(json['address']);
    return CenterInfo(
      nameAr: nameAr,
      nameEn: nameEn,
      addressAr: addressAr,
      addressEn: addressEn,
      hoursAr: hoursAr,
      hoursEn: hoursEn,
      mapUrl: AppConfigData._httpsUrl(json['map_url']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': {'ar': nameAr, 'en': nameEn},
    'address': {'ar': addressAr, 'en': addressEn},
    'hours': {'ar': hoursAr, 'en': hoursEn},
    'map_url': mapUrl,
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
