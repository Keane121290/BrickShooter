import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/player_profile.dart';

class EmeraldPack {
  const EmeraldPack({
    required this.id,
    required this.emeralds,
    required this.title,
  });

  final String id;
  final int emeralds;
  final String title;
}

class EmeraldShop {
  EmeraldShop(this.profile);

  static const packs = <EmeraldPack>[
    EmeraldPack(id: 'brickshooter_emeralds_30', emeralds: 30, title: 'Pouch'),
    EmeraldPack(id: 'brickshooter_emeralds_80', emeralds: 80, title: 'Chest'),
    EmeraldPack(id: 'brickshooter_emeralds_200', emeralds: 200, title: 'Vault'),
  ];

  final PlayerProfile profile;
  final Map<String, ProductDetails> products = {};
  InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  var available = false;

  Future<void> start() async {
    try {
      final iap = InAppPurchase.instance;
      _iap = iap;
      _sub ??= iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object error) {
          debugPrint('Emerald purchase stream failed: $error');
        },
      );
      available = await iap.isAvailable();
      if (!available) return;
      final response = await iap.queryProductDetails(
        packs.map((pack) => pack.id).toSet(),
      );
      for (final product in response.productDetails) {
        products[product.id] = product;
      }
    } catch (error) {
      debugPrint('Emerald store query failed: $error');
      available = false;
    }
  }

  String priceLabel(EmeraldPack pack) {
    return products[pack.id]?.price ?? 'Store';
  }

  Future<bool> buy(EmeraldPack pack) async {
    final iap = _iap;
    final product = products[pack.id];
    if (!available || product == null || iap == null) return false;
    final started = await iap.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    return started;
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    final iap = _iap;
    if (iap == null) return;
    final prefs = await SharedPreferences.getInstance();
    final granted = prefs.getStringList('grantedPurchases') ?? <String>[];
    for (final purchase in purchases) {
      EmeraldPack? pack;
      for (final item in packs) {
        if (item.id == purchase.productID) pack = item;
      }
      final receipt = purchase.purchaseID;
      final alreadyGranted = receipt != null && granted.contains(receipt);
      if (!alreadyGranted &&
          pack != null &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored)) {
        profile.addEmeralds(pack.emeralds);
        if (receipt != null) granted.add(receipt);
      }
      if (purchase.pendingCompletePurchase) {
        await iap.completePurchase(purchase);
      }
    }
    await prefs.setStringList('grantedPurchases', granted);
  }

  void dispose() {
    _sub?.cancel();
  }
}
