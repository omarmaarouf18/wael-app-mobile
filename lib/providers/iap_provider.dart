import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/store_policy.dart';
import '../models/iap_package.dart';
import '../repositories/iap_repository.dart';
import '../services/iap_service.dart';

enum IapCatalogStatus { idle, loading, ready, error }

/// iOS subject packages (issue #57): the server's package list, StoreKit's
/// products and prices, and the purchase state from [IapService]. Off iOS
/// (`StorePolicy.iapEnabled()` false) every method is a no-op: no IAP
/// route is called and StoreKit is never touched.
class IapProvider extends ChangeNotifier {
  IapProvider({
    required this._repository,
    required this._service,
    this._onEntitlementsChanged,
    this._platform,
  }) {
    if (enabled) _stateSub = _service.states.listen(_onPurchaseState);
  }

  final IapRepository _repository;
  final IapService _service;
  final TargetPlatform? _platform;

  /// Reloads the academy catalog (owned flags) after a grant.
  Future<void> Function()? _onEntitlementsChanged;

  StreamSubscription<IapPurchaseState>? _stateSub;
  bool _started = false;
  bool _disposed = false;
  int _generation = 0;

  IapCatalogStatus _status = IapCatalogStatus.idle;
  IapCatalog? _catalog;
  Map<String, IapStoreProduct> _products = const {};
  IapFailure? _error;

  bool get enabled => StorePolicy.iapEnabled(_platform);

  IapCatalogStatus get status => _status;
  IapCatalog? get catalog => _catalog;
  List<IapPackage> get packages => _catalog?.packages ?? const [];
  IapFailure? get error => _error;
  IapPurchaseState get purchase => _service.state;

  /// StoreKit's product (display price) for [package], or null when StoreKit
  /// does not know it (then the app offers no Buy button).
  IapStoreProduct? productFor(IapPackage package) =>
      _products[package.productId];

  /// Buy is offered only for a package on sale that StoreKit knows, while
  /// nothing else is in progress.
  bool canBuy(IapPackage package) =>
      enabled &&
      _catalog != null &&
      package.onSale &&
      !package.allOwned &&
      productFor(package) != null &&
      !_busy;

  bool get _busy => switch (_service.state.phase) {
    IapPhase.loading || IapPhase.purchasing || IapPhase.verifying => true,
    _ => false,
  };

  void attachCatalogReload(Future<void> Function()? reload) {
    _onEntitlementsChanged = reload;
  }

  /// Called from the auth proxy (during build: must not notify
  /// synchronously). Starts the StoreKit listener once, then tells the
  /// service whether held transactions may be sent.
  void bindSession({required bool authenticated}) {
    if (!enabled || _disposed) return;
    if (!_started) {
      _started = true;
      unawaited(_service.start());
    }
    _service.setSignedIn(authenticated);
    if (!authenticated &&
        (_catalog != null || _status != IapCatalogStatus.idle)) {
      _generation++;
      _catalog = null;
      _products = const {};
      _error = null;
      _status = IapCatalogStatus.idle;
      scheduleMicrotask(_notify);
    }
  }

  /// Loads the package list, then StoreKit products for its Product IDs.
  Future<void> load() async {
    if (!enabled || _disposed) return;
    final gen = ++_generation;
    _status = IapCatalogStatus.loading;
    _error = null;
    _notify();
    try {
      final catalog = await _repository.fetchPackages();
      if (gen != _generation) return;
      final ids = {for (final p in catalog.packages) p.productId};
      final products = await _service.loadProducts(ids);
      if (gen != _generation) return;
      _catalog = catalog;
      _products = {for (final p in products) p.id: p};
      _status = IapCatalogStatus.ready;
    } on IapFailure catch (f) {
      if (gen != _generation) return;
      _error = f;
      _status = IapCatalogStatus.error;
    } on Exception {
      if (gen != _generation) return;
      _error = const IapFailure(IapFailureCode.unknown);
      _status = IapCatalogStatus.error;
    }
    _notify();
  }

  Future<void> buy(IapPackage package) async {
    final catalog = _catalog;
    if (catalog == null || !canBuy(package)) return;
    await _service.buy(package, appAccountToken: catalog.appAccountToken);
  }

  Future<void> restore() async {
    if (!enabled || _busy) return;
    await _service.restore();
  }

  void _onPurchaseState(IapPurchaseState s) {
    _notify();
    if (s.phase == IapPhase.success) unawaited(_refreshAfterGrant());
  }

  Future<void> _refreshAfterGrant() async {
    final reload = _onEntitlementsChanged;
    await Future.wait([
      if (_catalog != null) load(),
      // The catalog provider shows its own errors; a failed reload here
      // must not surface as an unhandled error.
      if (reload != null) reload().catchError((Object _) {}),
    ]);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_stateSub?.cancel());
    unawaited(_service.dispose());
    super.dispose();
  }
}
