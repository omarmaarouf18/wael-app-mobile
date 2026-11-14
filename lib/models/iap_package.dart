/// Dart models for the iOS In-App Purchase routes of academy-service
/// (issue #57; contract: IAP brief Section 3, to be mirrored in
/// `docs/contracts/iap-packages-api.md` by issue #51):
///
/// * `GET /api/v1/academy/iap/packages` -> [IapCatalog]
/// * `POST /api/v1/academy/iap/transactions` -> [IapTransactionResult]
///
/// Unknown fields are ignored. Required fields that are missing or of the
/// wrong type raise [AcademyParseException], like the catalog models. The
/// API never carries a price: the app shows the price StoreKit returns.
library;

import 'academy_catalog.dart';

export 'academy_catalog.dart' show AcademyParseException, LocalizedText;

Map<String, dynamic> _map(Object? json, String what) {
  if (json is Map<String, dynamic>) return json;
  throw AcademyParseException('$what: expected an object');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v is String && v.isNotEmpty) return v;
  throw AcademyParseException('missing or empty "$key"');
}

String _string(Map<String, dynamic> json, String key) {
  final v = json[key];
  return v is String ? v : '';
}

int _int(Map<String, dynamic> json, String key, {int fallback = 0}) {
  final v = json[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return fallback;
}

bool _bool(Map<String, dynamic> json, String key) => json[key] == true;

/// A list the server may omit or send as `null` (a Go nil slice): both mean
/// empty. Any other non-list value is a contract error.
List<Object?> _optionalList(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v == null) return const [];
  if (v is List) return v;
  throw AcademyParseException('"$key" is not a list');
}

LocalizedText _text(Map<String, dynamic> json, String key) {
  final v = json[key];
  return v == null ? const LocalizedText() : LocalizedText.fromJson(v);
}

/// RFC 3339 `available_until`, or null (`null`, absent, empty, Go's zero
/// time or unparsable all mean "no end date").
DateTime? _optionalTime(Object? v) {
  if (v is! String || v.isEmpty) return null;
  final parsed = DateTime.tryParse(v);
  if (parsed == null || parsed.year <= 1) return null;
  return parsed.toUtc();
}

/// Canonical 8-4-4-4-12 hex UUID. StoreKit 2 silently drops an
/// `appAccountToken` that is not a UUID (the plugin calls
/// `UUID(uuidString:)` and skips the option on nil), which the server would
/// then refuse with `account_mismatch`; so a malformed token is a contract
/// error here, before any purchase starts.
final RegExp _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// `GET /academy/iap/packages`: the published packages and the token the
/// app passes to StoreKit as `appAccountToken`.
class IapCatalog {
  const IapCatalog({required this.appAccountToken, required this.packages});

  /// UUID v5 of the user id (deterministic, not stored by the server).
  final String appAccountToken;

  /// Published packages, in the server's order (`position`, then title).
  final List<IapPackage> packages;

  factory IapCatalog.fromJson(Map<String, dynamic> json) {
    final token = _requiredString(json, 'app_account_token');
    if (!_uuid.hasMatch(token)) {
      throw AcademyParseException('"app_account_token" is not a UUID');
    }
    return IapCatalog(
      appAccountToken: token,
      packages: _optionalList(json, 'packages')
          .map((e) => IapPackage.fromJson(_map(e, 'package')))
          .toList(growable: false),
    );
  }

  /// The package sold under [productId], or null.
  IapPackage? byProductId(String productId) {
    for (final p in packages) {
      if (p.productId == productId) return p;
    }
    return null;
  }
}

/// One package of subjects sold as an App Store product.
class IapPackage {
  const IapPackage({
    required this.id,
    required this.productId,
    required this.title,
    this.description = const LocalizedText(),
    this.availableUntil,
    this.onSale = false,
    this.position = 0,
    this.subjects = const [],
  });

  final String id;

  /// App Store Connect Product ID (for example `com.wael.app.pkg.year1`).
  final String productId;
  final LocalizedText title;
  final LocalizedText description;

  /// What the app shows ("available until ..."); null = no end date. It
  /// never limits what a valid Apple transaction grants (server side).
  final DateTime? availableUntil;

  /// Server-computed: published, not past [availableUntil], at least one
  /// subject. The app offers Buy only when this is true.
  final bool onSale;
  final int position;
  final List<IapPackageSubject> subjects;

  /// True when the student already owns every listed subject.
  bool get allOwned => subjects.isNotEmpty && subjects.every((s) => s.owned);

  factory IapPackage.fromJson(Map<String, dynamic> json) => IapPackage(
    id: _requiredString(json, 'id'),
    productId: _requiredString(json, 'product_id'),
    title: _text(json, 'title'),
    description: _text(json, 'description'),
    availableUntil: _optionalTime(json['available_until']),
    onSale: _bool(json, 'on_sale'),
    position: _int(json, 'position'),
    subjects: _optionalList(json, 'subjects')
        .map((e) => IapPackageSubject.fromJson(_map(e, 'package subject')))
        .toList(growable: false),
  );
}

/// A subject listed in a package.
class IapPackageSubject {
  const IapPackageSubject({
    required this.id,
    required this.title,
    this.levelKey = '',
    this.term = '',
    this.owned = false,
  });

  final String id;
  final LocalizedText title;
  final String levelKey;
  final String term;

  /// The caller has an active entitlement to this subject.
  final bool owned;

  factory IapPackageSubject.fromJson(Map<String, dynamic> json) =>
      IapPackageSubject(
        id: _requiredString(json, 'id'),
        title: _text(json, 'title'),
        levelKey: _string(json, 'level_key'),
        term: _string(json, 'term'),
        owned: _bool(json, 'owned'),
      );
}

enum IapTransactionStatus {
  /// First time this transaction was processed: subjects were granted.
  granted,

  /// The same transaction again by the same user (a retry or a restore):
  /// the stored result, nothing new granted.
  alreadyProcessed,

  /// A status this app version does not know. Still a 200: the server
  /// accepted the transaction.
  unknown,
}

/// Why a subject of the package was not granted.
class IapSkippedSubject {
  const IapSkippedSubject({required this.subjectId, required this.reason});

  final String subjectId;

  /// `already_owned` | `expired` | `unavailable`; other values are kept
  /// as sent.
  final String reason;

  factory IapSkippedSubject.fromJson(Map<String, dynamic> json) =>
      IapSkippedSubject(
        subjectId: _string(json, 'subject_id'),
        reason: _string(json, 'reason'),
      );
}

/// 200 answer of `POST /academy/iap/transactions`.
class IapTransactionResult {
  const IapTransactionResult({
    required this.status,
    this.transactionId = '',
    this.productId = '',
    this.packageId = '',
    this.grantedSubjectIds = const [],
    this.skipped = const [],
  });

  final IapTransactionStatus status;
  final String transactionId;
  final String productId;
  final String packageId;
  final List<String> grantedSubjectIds;
  final List<IapSkippedSubject> skipped;

  factory IapTransactionResult.fromJson(Map<String, dynamic> json) {
    final raw = _requiredString(json, 'status');
    final status = switch (raw) {
      'granted' => IapTransactionStatus.granted,
      'already_processed' => IapTransactionStatus.alreadyProcessed,
      _ => IapTransactionStatus.unknown,
    };
    return IapTransactionResult(
      status: status,
      transactionId: _string(json, 'transaction_id'),
      productId: _string(json, 'product_id'),
      packageId: _string(json, 'package_id'),
      grantedSubjectIds: _optionalList(
        json,
        'granted_subject_ids',
      ).whereType<String>().toList(growable: false),
      skipped: _optionalList(json, 'skipped')
          .map((e) => IapSkippedSubject.fromJson(_map(e, 'skipped subject')))
          .toList(growable: false),
    );
  }
}
