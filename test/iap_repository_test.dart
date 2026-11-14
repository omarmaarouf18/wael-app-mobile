import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/models/iap_package.dart';
import 'package:wael_app/repositories/iap_repository.dart';

import 'iap_fakes.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

class _Harness {
  _Harness(this.handler);

  final Future<http.Response> Function(http.Request) handler;
  final List<http.Request> requests = [];

  late final HttpIapRepository repo = HttpIapRepository(
    ApiClient(
      baseUrl: 'https://gateway.test',
      client: MockClient((req) async {
        requests.add(req);
        return handler(req);
      }),
      accessTokenReader: () async => 'access-1',
      refreshTokens: () async => false,
      forceLogout: () async {},
    ),
  );
}

void main() {
  test('fetchPackages GETs /api/v1/academy/iap/packages', () async {
    final h = _Harness((_) async => _json(packagesJson()));
    final c = await h.repo.fetchPackages();
    expect(c.packages.single.productId, 'com.wael.app.pkg.year1');
    final req = h.requests.single;
    expect(req.method, 'GET');
    expect(req.url.path, '/api/v1/academy/iap/packages');
    expect(req.headers['Authorization'], 'Bearer access-1');
  });

  test('submitTransaction POSTs only signed_transaction', () async {
    final h = _Harness((_) async => _json(grantedJson()));
    final r = await h.repo.submitTransaction('a.b.c');
    expect(r.status, IapTransactionStatus.granted);
    final req = h.requests.single;
    expect(req.method, 'POST');
    expect(req.url.path, '/api/v1/academy/iap/transactions');
    expect(jsonDecode(req.body), {'signed_transaction': 'a.b.c'});
  });

  group('every contract error code maps to a typed failure', () {
    // The bool: the app finishes the StoreKit transaction (D4).
    const cases = <(int, String, IapFailureCode, bool)>[
      (400, 'invalid_body', IapFailureCode.invalidBody, false),
      (403, 'app_client_required', IapFailureCode.appClientRequired, false),
      (422, 'invalid_transaction', IapFailureCode.invalidTransaction, true),
      (422, 'wrong_bundle', IapFailureCode.wrongBundle, true),
      (422, 'revoked_transaction', IapFailureCode.revokedTransaction, true),
      (
        422,
        'unsupported_product_type',
        IapFailureCode.unsupportedProductType,
        true,
      ),
      (404, 'unknown_product', IapFailureCode.unknownProduct, false),
      (403, 'account_mismatch', IapFailureCode.accountMismatch, false),
      (
        409,
        'transaction_owned_by_other_user',
        IapFailureCode.transactionOwnedByOtherUser,
        true,
      ),
      (403, 'sandbox_not_allowed', IapFailureCode.sandboxNotAllowed, false),
      (503, 'iap_unavailable', IapFailureCode.iapUnavailable, false),
      (429, 'rate_limited', IapFailureCode.rateLimited, false),
      (503, 'something_else', IapFailureCode.iapUnavailable, false),
      (500, 'internal', IapFailureCode.unknown, false),
      (418, 'teapot', IapFailureCode.unknown, false),
    ];
    for (final (status, code, expected, finishes) in cases) {
      test('$status $code -> ${expected.name}', () async {
        final h = _Harness(
          (_) async => _json({'code': code, 'message': 'm'}, status),
        );
        await expectLater(
          h.repo.submitTransaction('a.b.c'),
          throwsA(
            isA<IapFailure>()
                .having((f) => f.code, 'code', expected)
                .having((f) => f.statusCode, 'status', status)
                .having((f) => f.serverCode, 'serverCode', code)
                .having(
                  (f) => f.finishesTransaction,
                  'finishesTransaction',
                  finishes,
                ),
          ),
        );
      });
    }
  });

  test('401 after a failed refresh is unauthorized', () async {
    final h = _Harness((_) async => _json({'code': 'unauthorized'}, 401));
    await expectLater(
      h.repo.fetchPackages(),
      throwsA(
        isA<IapFailure>().having(
          (f) => f.code,
          'code',
          IapFailureCode.unauthorized,
        ),
      ),
    );
  });

  test('no answer is a network failure', () async {
    final h = _Harness((_) async => throw const SocketException('down'));
    await expectLater(
      h.repo.submitTransaction('a.b.c'),
      throwsA(
        isA<IapFailure>()
            .having((f) => f.code, 'code', IapFailureCode.network)
            .having((f) => f.finishesTransaction, 'finishesTransaction', false),
      ),
    );
    final h2 = _Harness((_) async => throw http.ClientException('reset'));
    await expectLater(
      h2.repo.fetchPackages(),
      throwsA(
        isA<IapFailure>().having((f) => f.code, 'code', IapFailureCode.network),
      ),
    );
  });

  test('a 200 that breaks the contract is invalidResponse', () async {
    final h = _Harness((_) async => _json({'packages': []}));
    await expectLater(
      h.repo.fetchPackages(),
      throwsA(
        isA<IapFailure>().having(
          (f) => f.code,
          'code',
          IapFailureCode.invalidResponse,
        ),
      ),
    );
  });
}
