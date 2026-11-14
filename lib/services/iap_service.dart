import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/store_policy.dart';
import '../models/iap_package.dart';
import '../repositories/iap_repository.dart';
import 'iap_store.dart';

export 'iap_store.dart' show IapStore, IapStoreProduct, StoreKitIapStore;

enum IapPhase {
  idle,
  loading,
  purchasing,
  pending,
  verifying,
  success,
  cancelled,
  failed,
}

/// Where the current purchase or restore stands.
class IapPurchaseState {
  const IapPurchaseState(
    this.phase, {
    this.productId,
    this.errorCode,
    this.failure,
    this.result,
  });

  static const idle = IapPurchaseState(IapPhase.idle);

  final IapPhase phase;
  final String? productId;

  /// For [IapPhase.failed]: an [IapFailureCode] name when the server
  /// refused (then [failure] is set), otherwise a StoreKit / plugin code
  /// (for example `storekit_duplicate_product_object`) or one of
  /// `store_unavailable`, `missing_transaction`, `product_not_found`.
  final String? errorCode;
  final IapFailure? failure;

  /// For [IapPhase.success]: what the server granted.
  final IapTransactionResult? result;
}

/// iOS In-App Purchase of subject packages (issue #57): StoreKit purchase,
/// server verification, then `Transaction.finish()`.
///
/// Rules:
/// * Nothing here touches StoreKit unless `StorePolicy.iapEnabled()`; the
///   store is created lazily by [start], [buy], [loadProducts] or
///   [restore].
/// * A transaction is finished only after the server answered 200
///   (`granted` or `already_processed`). Any failure leaves it unfinished,
///   so StoreKit delivers it again on the next launch and it is re-sent.
/// * Transactions that arrive while nobody is signed in are held and sent
///   when [setSignedIn] turns true; transient failures are held too and
///   re-sent on [restore] or the next sign-in.
class IapService {
  IapService({
    required this._repository,
    IapStore Function()? storeFactory,
    this._platform,
  }) : _storeFactory = storeFactory ?? StoreKitIapStore.new;

  final IapRepository _repository;
  final IapStore Function() _storeFactory;
  final TargetPlatform? _platform;

  IapStore? _store;
  StreamSubscription<List<IapStoreTransaction>>? _sub;
  final StreamController<IapPurchaseState> _states =
      StreamController<IapPurchaseState>.broadcast();
  IapPurchaseState _state = IapPurchaseState.idle;
  bool _signedIn = false;
  bool _disposed = false;

  /// Accepted-by-StoreKit transactions waiting for the server, by id.
  final Map<String, IapStoreTransaction> _held = {};
  final Set<String> _inFlight = {};

  bool get enabled => StorePolicy.iapEnabled(_platform);

  IapPurchaseState get state => _state;
  Stream<IapPurchaseState> get states => _states.stream;

  /// Transactions waiting for the server (held or being sent).
  int get pendingSubmissions => _held.length;

  IapStore? _ensureStore() {
    if (!enabled || _disposed) return null;
    final existing = _store;
    if (existing != null) return existing;
    final store = _storeFactory();
    _store = store;
    _sub = store.transactions.listen(
      _onUpdates,
      onError: (Object e) => _emit(
        const IapPurchaseState(IapPhase.failed, errorCode: 'store_error'),
      ),
    );
    return store;
  }

  /// Starts listening to StoreKit (iOS only). Call once at app start, signed
  /// in or not: StoreKit delivers unfinished transactions to the listener.
  Future<void> start() async => _ensureStore();

  /// Whether a student session exists. Turning true sends held
  /// transactions to the server.
  void setSignedIn(bool signedIn) {
    _signedIn = signedIn;
    if (signedIn) _flushHeld();
  }

  /// StoreKit products (with display prices) for [productIds]. Empty off
  /// iOS or when the App Store is unavailable.
  Future<List<IapStoreProduct>> loadProducts(Set<String> productIds) async {
    final store = _ensureStore();
    if (store == null || productIds.isEmpty) return const [];
    if (!await store.isAvailable()) return const [];
    return store.queryProducts(productIds);
  }

  /// Starts buying [package] with the server's [appAccountToken]. The
  /// outcome arrives on [states].
  Future<void> buy(
    IapPackage package, {
    required String appAccountToken,
  }) async {
    final store = _ensureStore();
    if (store == null) return;
    final productId = package.productId;
    _emit(IapPurchaseState(IapPhase.purchasing, productId: productId));
    try {
      if (!await store.isAvailable()) {
        _emit(
          IapPurchaseState(
            IapPhase.failed,
            productId: productId,
            errorCode: 'store_unavailable',
          ),
        );
        return;
      }
      await store.buy(productId, appAccountToken: appAccountToken);
    } on IapStoreException catch (e) {
      _emit(
        IapPurchaseState(
          IapPhase.failed,
          productId: productId,
          errorCode: e.code,
        ),
      );
    }
  }

  /// Re-sends held transactions, then asks StoreKit for current
  /// entitlements; each comes back as a restored transaction and goes to
  /// the server (which answers `already_processed` for known ones).
  Future<void> restore() async {
    final store = _ensureStore();
    if (store == null) return;
    _emit(const IapPurchaseState(IapPhase.loading));
    _flushHeld();
    try {
      await store.restore();
    } on Exception catch (e) {
      final code = e is IapStoreException ? e.code : 'restore_failed';
      _emit(IapPurchaseState(IapPhase.failed, errorCode: code));
      return;
    }
    if (_state.phase == IapPhase.loading) _emit(IapPurchaseState.idle);
  }

  void _onUpdates(List<IapStoreTransaction> updates) {
    for (final t in updates) {
      switch (t.status) {
        case IapStoreStatus.pending:
          _emit(IapPurchaseState(IapPhase.pending, productId: t.productId));
        case IapStoreStatus.cancelled:
          _emit(IapPurchaseState(IapPhase.cancelled, productId: t.productId));
        case IapStoreStatus.error:
          _emit(
            IapPurchaseState(
              IapPhase.failed,
              productId: t.productId,
              errorCode: t.errorCode ?? 'store_error',
            ),
          );
        case IapStoreStatus.purchased:
        case IapStoreStatus.restored:
          final id = t.transactionId;
          if (id == null || id.isEmpty || t.jws.isEmpty) {
            _emit(
              IapPurchaseState(
                IapPhase.failed,
                productId: t.productId,
                errorCode: 'missing_transaction',
              ),
            );
            continue;
          }
          _held[id] = t;
          if (_signedIn) unawaited(_submit(t));
      }
    }
  }

  void _flushHeld() {
    for (final t in _held.values.toList()) {
      unawaited(_submit(t));
    }
  }

  Future<void> _submit(IapStoreTransaction t) async {
    final id = t.transactionId!;
    if (!_inFlight.add(id)) return;
    _emit(IapPurchaseState(IapPhase.verifying, productId: t.productId));
    try {
      final result = await _repository.submitTransaction(t.jws);
      _held.remove(id);
      if (t.needsCompletion) {
        try {
          await _store?.complete(t);
        } on Exception {
          // The server already granted. StoreKit re-delivers an unfinished
          // transaction and the server answers already_processed.
        }
      }
      _emit(
        IapPurchaseState(
          IapPhase.success,
          productId: t.productId,
          result: result,
        ),
      );
    } on IapFailure catch (f) {
      // Not finished: StoreKit re-delivers it on the next launch. Only a
      // transient failure is retried in this session.
      if (!f.isTransient) _held.remove(id);
      _emit(
        IapPurchaseState(
          IapPhase.failed,
          productId: t.productId,
          errorCode: f.code.name,
          failure: f,
        ),
      );
    } finally {
      _inFlight.remove(id);
    }
  }

  void _emit(IapPurchaseState s) {
    if (_disposed) return;
    _state = s;
    _states.add(s);
  }

  Future<void> dispose() async {
    _disposed = true;
    await _sub?.cancel();
    await _states.close();
  }
}
