import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

/// A product as StoreKit returns it. [price] is StoreKit's localized display
/// price: the only price the app ever shows (owner decision 2026-11-13).
class IapStoreProduct {
  const IapStoreProduct({
    required this.id,
    required this.price,
    this.title = '',
    this.description = '',
  });

  final String id;
  final String price;
  final String title;
  final String description;
}

enum IapStoreStatus { purchased, restored, pending, cancelled, error }

/// One StoreKit transaction update, without plugin types.
class IapStoreTransaction {
  const IapStoreTransaction({
    required this.productId,
    required this.status,
    this.transactionId,
    this.jws = '',
    this.errorCode,
    this.needsCompletion = false,
    this.handle,
  });

  final String productId;
  final IapStoreStatus status;

  /// StoreKit transaction id; null for pending / cancelled updates.
  final String? transactionId;

  /// The StoreKit 2 signed transaction (`VerificationResult
  /// .jwsRepresentation`); empty when StoreKit gave none.
  final String jws;

  /// StoreKit / plugin error code for [IapStoreStatus.error].
  final String? errorCode;

  /// The transaction must be finished (`completePurchase`) once the server
  /// has accepted it.
  final bool needsCompletion;

  /// The plugin object [IapStore.complete] needs; opaque to callers.
  final Object? handle;
}

/// A purchase could not be started (StoreKit threw before any update).
class IapStoreException implements Exception {
  const IapStoreException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => 'IapStoreException($code)';
}

/// The seam over the StoreKit plugin, so the service is tested with fakes
/// and nothing below it is touched off iOS.
abstract class IapStore {
  Future<bool> isAvailable();

  /// Products StoreKit knows among [ids]; unknown ids are left out.
  Future<List<IapStoreProduct>> queryProducts(Set<String> ids);

  /// Starts the App Store purchase sheet. The result arrives on
  /// [transactions]. Throws [IapStoreException] when StoreKit refuses to
  /// start (unknown product, an unfinished transaction for it, ...).
  Future<void> buy(String productId, {required String appAccountToken});

  /// Every transaction update. Listening starts StoreKit 2's
  /// `Transaction.updates`, which also delivers unfinished transactions
  /// once right after launch: that is how a submission the server did not
  /// accept is retried on the next launch.
  Stream<List<IapStoreTransaction>> get transactions;

  /// Finishes the transaction (`Transaction.finish()`).
  Future<void> complete(IapStoreTransaction transaction);

  /// Re-delivers current entitlements (StoreKit 2
  /// `Transaction.currentEntitlements`) as restored transactions.
  Future<void> restore();
}

/// [IapStore] over `in_app_purchase_storekit` (StoreKit 2 is its default
/// since 0.4.x; `enableStoreKit2()` is deprecated as a no-op). The plugin
/// is registered on first construction only, so creating this object is
/// the first and only point that touches StoreKit. Construct it only when
/// `StorePolicy.iapEnabled()` is true.
class StoreKitIapStore implements IapStore {
  StoreKitIapStore() {
    if (!_registered) {
      InAppPurchaseStoreKitPlatform.registerPlatform();
      _registered = true;
    }
  }

  static bool _registered = false;

  InAppPurchasePlatform get _platform => InAppPurchasePlatform.instance;

  final Map<String, ProductDetails> _products = {};

  @override
  Future<bool> isAvailable() => _platform.isAvailable();

  @override
  Future<List<IapStoreProduct>> queryProducts(Set<String> ids) async {
    if (ids.isEmpty) return const [];
    final res = await _platform.queryProductDetails(ids);
    for (final p in res.productDetails) {
      _products[p.id] = p;
    }
    return [
      for (final p in res.productDetails)
        IapStoreProduct(
          id: p.id,
          price: p.price,
          title: p.title,
          description: p.description,
        ),
    ];
  }

  @override
  Future<void> buy(String productId, {required String appAccountToken}) async {
    var details = _products[productId];
    if (details == null) {
      await queryProducts({productId});
      details = _products[productId];
    }
    if (details == null) {
      throw const IapStoreException('product_not_found');
    }
    try {
      // On StoreKit 2 the plugin forwards `applicationUserName` as the
      // `Product.PurchaseOption.appAccountToken(UUID)`.
      await _platform.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: details,
          applicationUserName: appAccountToken,
        ),
      );
    } on PlatformException catch (e) {
      throw IapStoreException(e.code, e.message);
    }
  }

  @override
  Stream<List<IapStoreTransaction>> get transactions => _platform.purchaseStream
      .map((list) => list.map(_convert).toList(growable: false));

  static IapStoreTransaction _convert(PurchaseDetails d) => IapStoreTransaction(
    productId: d.productID,
    status: switch (d.status) {
      PurchaseStatus.purchased => IapStoreStatus.purchased,
      PurchaseStatus.restored => IapStoreStatus.restored,
      PurchaseStatus.pending => IapStoreStatus.pending,
      PurchaseStatus.canceled => IapStoreStatus.cancelled,
      PurchaseStatus.error => IapStoreStatus.error,
    },
    transactionId: d.purchaseID,
    // StoreKit 2: `serverVerificationData` is the transaction's
    // `jwsRepresentation` (plugin: SK2TransactionMessage.receiptData).
    jws: d.verificationData.serverVerificationData,
    errorCode: d.error?.code,
    needsCompletion: d.pendingCompletePurchase,
    handle: d,
  );

  @override
  Future<void> complete(IapStoreTransaction transaction) async {
    final handle = transaction.handle;
    if (handle is PurchaseDetails && handle.purchaseID != null) {
      await _platform.completePurchase(handle);
    }
  }

  @override
  Future<void> restore() => _platform.restorePurchases();
}
