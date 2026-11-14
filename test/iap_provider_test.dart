import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/models/iap_package.dart';
import 'package:wael_app/providers/iap_provider.dart';
import 'package:wael_app/repositories/iap_repository.dart';
import 'package:wael_app/services/iap_service.dart';

import 'iap_fakes.dart';

Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeIapRepository repo;
  late FakeIapStore store;
  late IapProvider provider;
  late int catalogReloads;

  setUp(() {
    repo = FakeIapRepository();
    store = FakeIapStore();
    catalogReloads = 0;
    provider = IapProvider(
      repository: repo,
      service: IapService(
        repository: repo,
        storeFactory: () => store,
        platform: TargetPlatform.iOS,
      ),
      onEntitlementsChanged: () async => catalogReloads++,
      platform: TargetPlatform.iOS,
    );
  });

  tearDown(() => provider.dispose());

  test('load: packages from the server, prices from StoreKit only', () async {
    await provider.load();
    expect(provider.status, IapCatalogStatus.ready);
    final pkg = provider.packages.single;
    expect(store.queries.single, {'com.wael.app.pkg.year1'});
    expect(provider.productFor(pkg)!.price, 'EGP 500.00');
    expect(provider.canBuy(pkg), isTrue);
  });

  test('no Buy without a StoreKit product, off sale, or all owned', () async {
    store.known = {};
    await provider.load();
    expect(provider.canBuy(provider.packages.single), isFalse);

    store.known = FakeIapStore().known;
    repo.catalog = IapCatalog.fromJson(packagesJson(onSale: false));
    await provider.load();
    expect(provider.canBuy(provider.packages.single), isFalse);
  });

  test('load error is kept as a typed failure', () async {
    repo.fetchError = const IapFailure(IapFailureCode.appClientRequired);
    await provider.load();
    expect(provider.status, IapCatalogStatus.error);
    expect(provider.error!.code, IapFailureCode.appClientRequired);
  });

  test('success refreshes packages and the academy catalog', () async {
    provider.bindSession(authenticated: true);
    await provider.load();
    expect(repo.fetchCalls, 1);
    await provider.buy(provider.packages.single);
    expect(store.buys.single.$2, kToken);

    store.emit([purchased()]);
    await _settle();

    expect(provider.purchase.phase, IapPhase.success);
    expect(store.completed, hasLength(1));
    expect(repo.fetchCalls, 2);
    expect(catalogReloads, 1);
  });

  test('a server refusal refreshes nothing and finishes nothing', () async {
    repo.submitAnswers = [
      const IapFailure(IapFailureCode.sandboxNotAllowed, statusCode: 403),
    ];
    provider.bindSession(authenticated: true);
    await provider.load();
    await provider.buy(provider.packages.single);
    store.emit([purchased()]);
    await _settle();
    expect(provider.purchase.errorCode, 'sandboxNotAllowed');
    expect(store.completed, isEmpty);
    expect(catalogReloads, 0);
  });

  test('sign-out drops the per-student package data', () async {
    provider.bindSession(authenticated: true);
    await provider.load();
    provider.bindSession(authenticated: false);
    await _settle();
    expect(provider.catalog, isNull);
    expect(provider.status, IapCatalogStatus.idle);
  });
}
