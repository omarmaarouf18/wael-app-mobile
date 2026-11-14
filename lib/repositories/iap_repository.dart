import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http show ClientException;

import '../core/api_client.dart';
import '../models/iap_package.dart';

/// Every way an IAP call can fail, one value per contract error code
/// (IAP brief Section 3.2) plus the transport cases the app tells apart.
enum IapFailureCode {
  /// 400 `invalid_body`.
  invalidBody,

  /// 403 `app_client_required` (a web token).
  appClientRequired,

  /// 422 `invalid_transaction`: bad JWS, chain, signature, alg or fields.
  invalidTransaction,

  /// 422 `wrong_bundle`.
  wrongBundle,

  /// 422 `revoked_transaction` (Apple refunded or revoked it).
  revokedTransaction,

  /// 422 `unsupported_product_type`.
  unsupportedProductType,

  /// 404 `unknown_product`: no package holds this Product ID.
  unknownProduct,

  /// 403 `account_mismatch`: `appAccountToken` missing or not this user's.
  accountMismatch,

  /// 409 `transaction_owned_by_other_user`.
  transactionOwnedByOtherUser,

  /// 403 `sandbox_not_allowed`.
  sandboxNotAllowed,

  /// 503 `iap_unavailable` (store error on the server).
  iapUnavailable,

  /// 401 after the client's refresh-once (the session ended).
  unauthorized,

  /// 429 (gateway or write rate limit).
  rateLimited,

  /// No answer: timeout, socket or client error.
  network,

  /// A 2xx whose body does not match the contract.
  invalidResponse,

  /// Any other status or code (including other 5xx).
  unknown,
}

/// A failed IAP call, mapped from the server's `code` (and status).
class IapFailure implements Exception {
  const IapFailure(this.code, {this.statusCode, this.serverCode});

  final IapFailureCode code;

  /// HTTP status, or null when there was no answer.
  final int? statusCode;

  /// The server's raw `code`, kept for logs and unknown values.
  final String? serverCode;

  /// A permanent refusal after which the app finishes the StoreKit
  /// transaction (owner decision D4, 2026-11-14): sending it again can
  /// never succeed. Every other failure (network, 5xx, `iap_unavailable`,
  /// `unknown_product`, `sandbox_not_allowed`, `account_mismatch`, auth)
  /// leaves it unfinished, so it is re-sent on the next submit or launch.
  bool get finishesTransaction => switch (code) {
    IapFailureCode.invalidTransaction ||
    IapFailureCode.wrongBundle ||
    IapFailureCode.unsupportedProductType ||
    IapFailureCode.revokedTransaction ||
    IapFailureCode.transactionOwnedByOtherUser => true,
    _ => false,
  };

  static const Map<String, IapFailureCode> _byServerCode = {
    'invalid_body': IapFailureCode.invalidBody,
    'app_client_required': IapFailureCode.appClientRequired,
    'invalid_transaction': IapFailureCode.invalidTransaction,
    'wrong_bundle': IapFailureCode.wrongBundle,
    'revoked_transaction': IapFailureCode.revokedTransaction,
    'unsupported_product_type': IapFailureCode.unsupportedProductType,
    'unknown_product': IapFailureCode.unknownProduct,
    'account_mismatch': IapFailureCode.accountMismatch,
    'transaction_owned_by_other_user':
        IapFailureCode.transactionOwnedByOtherUser,
    'sandbox_not_allowed': IapFailureCode.sandboxNotAllowed,
    'iap_unavailable': IapFailureCode.iapUnavailable,
  };

  /// Maps an [ApiException]: a known contract `code` wins; then the status.
  /// A timeout from [ApiClient] (status -1, code `timeout`) is [network].
  factory IapFailure.fromApi(ApiException e) {
    final known = e.code == null ? null : _byServerCode[e.code];
    final IapFailureCode code;
    if (known != null) {
      code = known;
    } else if (e.statusCode == -1 || e.code == 'timeout') {
      code = IapFailureCode.network;
    } else if (e.statusCode == 401) {
      code = IapFailureCode.unauthorized;
    } else if (e.statusCode == 429) {
      code = IapFailureCode.rateLimited;
    } else if (e.statusCode == 503) {
      code = IapFailureCode.iapUnavailable;
    } else {
      code = IapFailureCode.unknown;
    }
    return IapFailure(
      code,
      statusCode: e.statusCode == -1 ? null : e.statusCode,
      serverCode: e.code,
    );
  }

  @override
  String toString() =>
      'IapFailure(${code.name}, status: $statusCode, code: $serverCode)';
}

/// The academy-service IAP student routes (iOS only; callers check
/// `StorePolicy.iapEnabled()` first). Every failure is an [IapFailure].
abstract class IapRepository {
  /// `GET /academy/iap/packages`.
  Future<IapCatalog> fetchPackages();

  /// `POST /academy/iap/transactions` with the StoreKit 2 signed
  /// transaction (JWS). Also used by restore: a known transaction answers
  /// `already_processed`.
  Future<IapTransactionResult> submitTransaction(String jws);
}

/// [IapRepository] over the authed gateway client (a 401 runs the usual
/// refresh-once-then-logout flow inside [ApiClient]).
class HttpIapRepository implements IapRepository {
  HttpIapRepository(this._api);

  final ApiClient _api;

  static const _base = '/api/v1/academy/iap';

  @override
  Future<IapCatalog> fetchPackages() => _guard(
    () async => IapCatalog.fromJson(await _api.get('$_base/packages')),
  );

  @override
  Future<IapTransactionResult> submitTransaction(String jws) => _guard(
    () async => IapTransactionResult.fromJson(
      await _api.post('$_base/transactions', body: {'signed_transaction': jws}),
    ),
  );

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      throw IapFailure.fromApi(e);
    } on AcademyParseException {
      throw const IapFailure(IapFailureCode.invalidResponse, statusCode: 200);
    } on TimeoutException {
      throw const IapFailure(IapFailureCode.network);
    } on SocketException {
      throw const IapFailure(IapFailureCode.network);
    } on http.ClientException {
      throw const IapFailure(IapFailureCode.network);
    }
  }
}
