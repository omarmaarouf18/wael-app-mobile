import 'dart:async';

import 'package:wael_app/models/iap_package.dart';
import 'package:wael_app/repositories/iap_repository.dart';
import 'package:wael_app/services/iap_store.dart';

const kToken = '8c7e2b1a-4f3d-5a6b-9c8d-0e1f2a3b4c5d';

/// The contract example of `GET /academy/iap/packages` (IAP brief 3.1),
/// with the token made a full UUID.
Map<String, dynamic> packagesJson({
  bool onSale = true,
  Object? availableUntil = '2027-01-20T00:00:00Z',
  bool owned = false,
}) => {
  'app_account_token': kToken,
  'packages': [
    {
      'id': 'pkg_1',
      'product_id': 'com.wael.app.pkg.year1',
      'title': {'ar': 'الفرقة الأولى', 'en': 'Year 1'},
      'description': {'ar': '', 'en': ''},
      'available_until': availableUntil,
      'on_sale': onSale,
      'position': 1,
      'subjects': [
        {
          'id': 'subj_a',
          'title': {'ar': 'مادة', 'en': 'Subject'},
          'level_key': 'bachelor-y1',
          'term': 'first',
          'owned': owned,
        },
      ],
    },
  ],
};

/// The contract example of a 200 from `POST /academy/iap/transactions`.
Map<String, dynamic> grantedJson({String status = 'granted'}) => {
  'status': status,
  'transaction_id': '2000000123',
  'product_id': 'com.wael.app.pkg.year1',
  'package_id': 'pkg_1',
  'granted_subject_ids': ['subj_a'],
  'skipped': [
    {'subject_id': 'subj_b', 'reason': 'already_owned'},
  ],
};

class FakeIapRepository implements IapRepository {
  IapCatalog catalog = IapCatalog.fromJson(packagesJson());
  Object? fetchError;
  int fetchCalls = 0;

  /// Answers to `submitTransaction`, in order; the last one repeats. An
  /// [IapFailure] entry is thrown.
  List<Object> submitAnswers = [IapTransactionResult.fromJson(grantedJson())];
  final List<String> submitted = [];

  /// When set, `submitTransaction` waits for it.
  Completer<void>? submitGate;

  @override
  Future<IapCatalog> fetchPackages() async {
    fetchCalls++;
    final e = fetchError;
    if (e != null) throw e;
    return catalog;
  }

  @override
  Future<IapTransactionResult> submitTransaction(String jws) async {
    submitted.add(jws);
    await submitGate?.future;
    final i = submitted.length - 1;
    final a =
        submitAnswers[i < submitAnswers.length ? i : submitAnswers.length - 1];
    if (a is IapFailure) throw a;
    return a as IapTransactionResult;
  }
}

/// [IapStore] fake: records calls; tests push updates with [emit].
class FakeIapStore implements IapStore {
  bool available = true;
  Map<String, IapStoreProduct> known = {
    'com.wael.app.pkg.year1': const IapStoreProduct(
      id: 'com.wael.app.pkg.year1',
      price: 'EGP 500.00',
    ),
  };
  Object? buyError;
  Object? restoreError;

  final List<(String, String)> buys = [];
  final List<Set<String>> queries = [];
  final List<IapStoreTransaction> completed = [];
  int restoreCalls = 0;

  /// What `restore()` delivers on [transactions] before returning.
  List<IapStoreTransaction> restoreDelivers = const [];

  final StreamController<List<IapStoreTransaction>> _updates =
      StreamController<List<IapStoreTransaction>>.broadcast(sync: true);
  int listeners = 0;

  void emit(List<IapStoreTransaction> updates) => _updates.add(updates);

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<IapStoreProduct>> queryProducts(Set<String> ids) async {
    queries.add(ids);
    return [
      for (final id in ids)
        if (known[id] != null) known[id]!,
    ];
  }

  @override
  Future<void> buy(String productId, {required String appAccountToken}) async {
    buys.add((productId, appAccountToken));
    final e = buyError;
    if (e != null) throw e;
  }

  @override
  Stream<List<IapStoreTransaction>> get transactions {
    listeners++;
    return _updates.stream;
  }

  @override
  Future<void> complete(IapStoreTransaction transaction) async {
    completed.add(transaction);
  }

  @override
  Future<void> restore() async {
    restoreCalls++;
    final e = restoreError;
    if (e != null) throw e;
    if (restoreDelivers.isNotEmpty) emit(restoreDelivers);
  }
}

IapStoreTransaction purchased({
  String id = '2000000123',
  String jws = 'header.payload.sig',
  IapStoreStatus status = IapStoreStatus.purchased,
  bool needsCompletion = true,
}) => IapStoreTransaction(
  productId: 'com.wael.app.pkg.year1',
  status: status,
  transactionId: id,
  jws: jws,
  needsCompletion: needsCompletion,
);
