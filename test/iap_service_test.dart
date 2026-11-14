import 'dart:async' show Completer;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/models/iap_package.dart';
import 'package:wael_app/providers/iap_provider.dart';
import 'package:wael_app/repositories/iap_repository.dart';
import 'package:wael_app/services/iap_service.dart';
import 'package:wael_app/services/iap_store.dart';

import 'iap_fakes.dart';

/// Lets queued microtasks and stream events run.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Rig {
  _Rig({TargetPlatform? platform}) {
    service = IapService(
      repository: repo,
      storeFactory: () {
        storeCreated++;
        return store;
      },
      platform: platform,
      log: logs.add,
    );
    service.states.listen(phases.add);
  }

  final repo = FakeIapRepository();
  final store = FakeIapStore();
  late final IapService service;
  int storeCreated = 0;
  final List<IapPurchaseState> phases = [];
  final List<String> logs = [];

  List<IapPhase> get phaseNames => [for (final s in phases) s.phase];
  IapPackage get pkg => repo.catalog.packages.single;
}

void main() {
  group('IapService on iOS', () {
    test('purchase -> server 200 granted -> transaction completed', () async {
      final r = _Rig(platform: TargetPlatform.iOS);
      r.service.setSignedIn(true);
      await r.service.buy(r.pkg, appAccountToken: kToken);
      expect(r.store.buys.single, ('com.wael.app.pkg.year1', kToken));

      r.store.emit([purchased()]);
      await _settle();

      expect(r.repo.submitted, ['header.payload.sig']);
      expect(r.store.completed.single.transactionId, '2000000123');
      expect(r.phaseNames, [
        IapPhase.purchasing,
        IapPhase.verifying,
        IapPhase.success,
      ]);
      expect(r.service.state.result!.grantedSubjectIds, ['subj_a']);
      expect(r.service.pendingSubmissions, 0);
    });

    test('server already_processed -> completed, success', () async {
      final r = _Rig(platform: TargetPlatform.iOS);
      r.repo.submitAnswers = [
        IapTransactionResult.fromJson(grantedJson(status: 'already_processed')),
      ];
      r.service.setSignedIn(true);
      await r.service.start();
      r.store.emit([purchased()]);
      await _settle();
      expect(r.store.completed, hasLength(1));
      expect(r.service.state.phase, IapPhase.success);
      expect(
        r.service.state.result!.status,
        IapTransactionStatus.alreadyProcessed,
      );
    });

    // Owner decision D4 (2026-11-14): finish on exactly five permanent
    // refusals, keep every other failure unfinished and held.
    const finishCodes = {
      IapFailureCode.invalidTransaction: ('invalid_transaction', 422),
      IapFailureCode.wrongBundle: ('wrong_bundle', 422),
      IapFailureCode.unsupportedProductType: ('unsupported_product_type', 422),
      IapFailureCode.revokedTransaction: ('revoked_transaction', 422),
      IapFailureCode.transactionOwnedByOtherUser: (
        'transaction_owned_by_other_user',
        409,
      ),
    };
    const keepCodes = {
      IapFailureCode.invalidBody: ('invalid_body', 400),
      IapFailureCode.appClientRequired: ('app_client_required', 403),
      IapFailureCode.unknownProduct: ('unknown_product', 404),
      IapFailureCode.accountMismatch: ('account_mismatch', 403),
      IapFailureCode.sandboxNotAllowed: ('sandbox_not_allowed', 403),
      IapFailureCode.iapUnavailable: ('iap_unavailable', 503),
      IapFailureCode.unauthorized: ('unauthorized', 401),
      IapFailureCode.rateLimited: ('rate_limited', 429),
      IapFailureCode.invalidResponse: (null, 200),
      IapFailureCode.unknown: ('internal', 500),
    };
    test('every failure code is classified exactly once', () {
      expect({
        ...finishCodes.keys,
        ...keepCodes.keys,
        IapFailureCode.network,
      }, IapFailureCode.values.toSet());
    });

    for (final MapEntry(key: code, value: (server, status))
        in finishCodes.entries) {
      test('D4: ${code.name} -> finished, PII-free log, failed', () async {
        final r = _Rig(platform: TargetPlatform.iOS);
        final f = IapFailure(code, statusCode: status, serverCode: server);
        r.repo.submitAnswers = [f];
        r.service.setSignedIn(true);
        await r.service.start();
        r.store.emit([purchased()]);
        await _settle();
        expect(r.store.completed.single.transactionId, '2000000123');
        expect(r.service.state.phase, IapPhase.failed);
        expect(r.service.state.errorCode, code.name);
        expect(r.service.pendingSubmissions, 0);
        final line = r.logs.single;
        expect(line, contains(server));
        expect(line, contains('$status'));
        expect(line, isNot(contains('header.payload.sig')));
        expect(line, isNot(contains('2000000123')));
        expect(line, isNot(contains(kToken)));

        // Not re-sent on restore.
        await r.service.restore();
        await _settle();
        expect(r.repo.submitted, hasLength(1));
      });
    }

    for (final MapEntry(key: code, value: (server, status))
        in keepCodes.entries) {
      test('D4: ${code.name} -> NOT finished, held, no log', () async {
        final r = _Rig(platform: TargetPlatform.iOS);
        r.repo.submitAnswers = [
          IapFailure(code, statusCode: status, serverCode: server),
          IapTransactionResult.fromJson(grantedJson()),
        ];
        r.service.setSignedIn(true);
        await r.service.start();
        r.store.emit([purchased()]);
        await _settle();
        expect(r.store.completed, isEmpty);
        expect(r.service.state.errorCode, code.name);
        expect(r.service.pendingSubmissions, 1);
        expect(r.logs, isEmpty);

        // Re-sent on the next submit (restore) and finished on 200.
        await r.service.restore();
        await _settle();
        expect(r.repo.submitted, hasLength(2));
        expect(r.store.completed, hasLength(1));
      });
    }

    test('D4: a network failure -> NOT finished, held', () async {
      final r = _Rig(platform: TargetPlatform.iOS);
      r.repo.submitAnswers = [const IapFailure(IapFailureCode.network)];
      r.service.setSignedIn(true);
      await r.service.start();
      r.store.emit([purchased()]);
      await _settle();
      expect(r.store.completed, isEmpty);
      expect(r.service.pendingSubmissions, 1);
      expect(r.logs, isEmpty);
    });

    test(
      'D4: account_mismatch is re-sent when another account signs in',
      () async {
        final r = _Rig(platform: TargetPlatform.iOS);
        r.repo.submitAnswers = [
          const IapFailure(IapFailureCode.accountMismatch, statusCode: 403),
          IapTransactionResult.fromJson(grantedJson()),
        ];
        r.service.setSignedIn(true);
        await r.service.start();
        r.store.emit([purchased()]);
        await _settle();
        r.service.setSignedIn(false);
        r.service.setSignedIn(true);
        await _settle();
        expect(r.repo.submitted, hasLength(2));
        expect(r.store.completed, hasLength(1));
      },
    );

    test(
      'a transient failure is re-sent on restore and then completed',
      () async {
        final r = _Rig(platform: TargetPlatform.iOS);
        r.repo.submitAnswers = [
          const IapFailure(IapFailureCode.network),
          IapTransactionResult.fromJson(grantedJson()),
        ];
        r.service.setSignedIn(true);
        await r.service.start();
        r.store.emit([purchased()]);
        await _settle();
        expect(r.store.completed, isEmpty);

        await r.service.restore();
        await _settle();
        expect(r.repo.submitted, hasLength(2));
        expect(r.store.completed, hasLength(1));
        expect(r.service.pendingSubmissions, 0);
      },
    );

    test('cancelled -> cancelled, nothing sent or completed', () async {
      final r = _Rig(platform: TargetPlatform.iOS);
      r.service.setSignedIn(true);
      await r.service.buy(r.pkg, appAccountToken: kToken);
      r.store.emit([
        const IapStoreTransaction(
          productId: 'com.wael.app.pkg.year1',
          status: IapStoreStatus.cancelled,
        ),
      ]);
      await _settle();
      expect(r.service.state.phase, IapPhase.cancelled);
      expect(r.repo.submitted, isEmpty);
      expect(r.store.completed, isEmpty);
    });

    test('pending (Ask to Buy) -> pending, nothing sent', () async {
      final r = _Rig(platform: TargetPlatform.iOS);
      r.service.setSignedIn(true);
      await r.service.start();
      r.store.emit([
        const IapStoreTransaction(
          productId: 'com.wael.app.pkg.year1',
          status: IapStoreStatus.pending,
        ),
      ]);
      await _settle();
      expect(r.service.state.phase, IapPhase.pending);
      expect(r.repo.submitted, isEmpty);
    });

    test(
      'store error and refused start -> failed with the store code',
      () async {
        final r = _Rig(platform: TargetPlatform.iOS);
        r.service.setSignedIn(true);
        await r.service.start();
        r.store.emit([
          const IapStoreTransaction(
            productId: 'com.wael.app.pkg.year1',
            status: IapStoreStatus.error,
            errorCode: 'storekit2_purchase_failed',
          ),
        ]);
        await _settle();
        expect(r.service.state.errorCode, 'storekit2_purchase_failed');

        r.store.buyError = const IapStoreException(
          'storekit_duplicate_product_object',
        );
        await r.service.buy(r.pkg, appAccountToken: kToken);
        expect(r.service.state.phase, IapPhase.failed);
        expect(r.service.state.errorCode, 'storekit_duplicate_product_object');
        expect(r.repo.submitted, isEmpty);
      },
    );

    test('App Store unavailable -> failed, no purchase sheet', () async {
      final r = _Rig(platform: TargetPlatform.iOS);
      r.store.available = false;
      await r.service.buy(r.pkg, appAccountToken: kToken);
      expect(r.store.buys, isEmpty);
      expect(r.service.state.errorCode, 'store_unavailable');
      expect(await r.service.loadProducts({'com.wael.app.pkg.year1'}), isEmpty);
    });

    test('a transaction without JWS is not sent nor completed', () async {
      final r = _Rig(platform: TargetPlatform.iOS);
      r.service.setSignedIn(true);
      await r.service.start();
      r.store.emit([purchased(jws: '')]);
      await _settle();
      expect(r.service.state.errorCode, 'missing_transaction');
      expect(r.repo.submitted, isEmpty);
      expect(r.store.completed, isEmpty);
    });

    test('unfinished transactions at launch wait for sign-in', () async {
      final r = _Rig(platform: TargetPlatform.iOS);
      await r.service.start();
      expect(r.store.listeners, 1);
      // StoreKit re-delivers an unfinished transaction at launch.
      r.store.emit([purchased()]);
      await _settle();
      expect(r.repo.submitted, isEmpty);
      expect(r.service.pendingSubmissions, 1);

      r.service.setSignedIn(true);
      await _settle();
      expect(r.repo.submitted, ['header.payload.sig']);
      expect(r.store.completed, hasLength(1));
    });

    test(
      'the same transaction delivered twice is sent once at a time',
      () async {
        final r = _Rig(platform: TargetPlatform.iOS);
        r.repo.submitGate = Completer<void>();
        r.service.setSignedIn(true);
        await r.service.start();
        r.store.emit([purchased(), purchased()]);
        await _settle();
        expect(r.repo.submitted, hasLength(1));
        r.repo.submitGate!.complete();
        await _settle();
        expect(r.store.completed, hasLength(1));
      },
    );

    test('restore re-submits entitlements; restored ones are not '
        're-finished', () async {
      final r = _Rig(platform: TargetPlatform.iOS);
      r.repo.submitAnswers = [
        IapTransactionResult.fromJson(grantedJson(status: 'already_processed')),
      ];
      r.store.restoreDelivers = [
        purchased(status: IapStoreStatus.restored, needsCompletion: false),
      ];
      r.service.setSignedIn(true);
      await r.service.restore();
      await _settle();
      expect(r.store.restoreCalls, 1);
      expect(r.repo.submitted, hasLength(1));
      expect(r.store.completed, isEmpty);
      expect(r.phaseNames.first, IapPhase.loading);
      expect(r.service.state.phase, IapPhase.success);
    });

    test('restore with nothing to restore ends idle', () async {
      final r = _Rig(platform: TargetPlatform.iOS);
      r.service.setSignedIn(true);
      await r.service.restore();
      expect(r.service.state.phase, IapPhase.idle);
    });
  });

  // The plugin must never be touched off iOS (owner decision 2026-11-13:
  // Android stays as it is).
  testWidgets(
    'Android: StoreKit is never created and no IAP route is called',
    (tester) async {
      final r = _Rig();
      expect(r.service.enabled, isFalse);
      await r.service.start();
      r.service.setSignedIn(true);
      await r.service.buy(r.pkg, appAccountToken: kToken);
      await r.service.restore();
      expect(await r.service.loadProducts({'com.wael.app.pkg.year1'}), isEmpty);

      final provider = IapProvider(repository: r.repo, service: r.service);
      provider.bindSession(authenticated: true);
      await provider.load();
      await provider.buy(r.pkg);
      await provider.restore();

      expect(r.storeCreated, 0);
      expect(r.repo.fetchCalls, 0);
      expect(r.repo.submitted, isEmpty);
      expect(provider.status, IapCatalogStatus.idle);
      expect(provider.enabled, isFalse);
      provider.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'iOS (default platform): the store is created once and used',
    (tester) async {
      // Real async: the service's futures and streams are not fake-timed.
      await tester.runAsync(() async {
        final r = _Rig();
        expect(r.service.enabled, isTrue);
        await r.service.start();
        await r.service.start();
        expect(r.storeCreated, 1);
        final products = await r.service.loadProducts({
          'com.wael.app.pkg.year1',
          'com.wael.app.pkg.year2',
        });
        expect(products.single.price, 'EGP 500.00');
        await r.service.dispose();
      });
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
