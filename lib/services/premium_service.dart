import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'subscription_offers.dart';

// Subscription product IDs. These must match the subscriptions created in
// Google Play Console (Monetize > Subscriptions), each with one base plan.
// The yearly base plan also has a 7-day free trial offer for new
// subscribers, set up in Play Console (no code needed per offer).
const String kPremiumMonthlyId = 'premium_monthly';
const String kPremiumYearlyId = 'premium_yearly';
const Set<String> kPremiumProductIds = {kPremiumMonthlyId, kPremiumYearlyId};

// Access code for Google Play reviewers and testers (they can't buy
// subscriptions or use free trials). Only the SHA-256 hash of the code is
// in the app; the code itself is kept outside git. To rotate it, generate a
// new code, replace this hash and ship an update.
const String kAccessCodeHash =
    'c4ec79e4015f40691d8948d991dfb344338bf8ac207c5cce75ab7d9259d94eb6';
const Duration kAccessCodeDuration = Duration(days: 30);

/// Hash of an access code, ignoring case, spaces and hyphens.
@visibleForTesting
String accessCodeHash(String code) {
  final normalised = code.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  return sha256
      .convert(utf8.encode('parentinghelper-access:$normalised'))
      .toString();
}

// Shown until the store returns localised prices.
const String kFallbackMonthlyPrice = '\$2.99';
const String kFallbackYearlyPrice = '\$19.99';

/// Single source of truth for whether the Premium plan is active.
///
/// Premium is granted by an active Google Play subscription. The last known
/// state is cached so the app works offline, and re-checked against Google
/// Play on every start so a cancelled subscription is picked up.
class PremiumService extends ChangeNotifier {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  static const _premiumKey = 'is_premium';
  static const _accessUntilKey = 'access_code_until';

  bool _hasSubscription = false;
  DateTime? _accessCodeUntil;
  bool storeAvailable = false;
  bool purchasePending = false;
  String? lastError;
  Map<String, SelectedPlan> plans = {};

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  /// Premium comes from an active Google Play subscription, or from a
  /// reviewer/tester access code that hasn't expired.
  bool get isPremium => _hasSubscription || accessCodeActive;

  bool get hasSubscription => _hasSubscription;
  DateTime? get accessCodeUntil => accessCodeActive ? _accessCodeUntil : null;
  bool get accessCodeActive =>
      _accessCodeUntil != null && DateTime.now().isBefore(_accessCodeUntil!);

  /// Unlocks Premium on this device for [kAccessCodeDuration] if [code]
  /// matches. Returns whether it did.
  Future<bool> redeemAccessCode(String code) async {
    if (accessCodeHash(code) != kAccessCodeHash) return false;
    _accessCodeUntil = DateTime.now().add(kAccessCodeDuration);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessUntilKey, _accessCodeUntil!.toIso8601String());
    notifyListeners();
    return true;
  }

  String get monthlyPrice =>
      plans[kPremiumMonthlyId]?.recurringPrice ?? kFallbackMonthlyPrice;
  String get yearlyPrice =>
      plans[kPremiumYearlyId]?.recurringPrice ?? kFallbackYearlyPrice;

  /// Free trial length on the yearly plan, when Google Play offers one to
  /// this user (only new subscribers are eligible).
  int? get yearlyTrialDays => plans[kPremiumYearlyId]?.trialDays;
  int? trialDaysFor(String productId) => plans[productId]?.trialDays;

  // Yearly vs 12 x monthly. Uses store prices only when both are loaded,
  // so the currencies match.
  int get yearlySavingsPercent {
    final monthly = plans[kPremiumMonthlyId]?.recurringRawPrice;
    final yearly = plans[kPremiumYearlyId]?.recurringRawPrice;
    final (m, y) = (monthly != null && yearly != null)
        ? (monthly, yearly)
        : (2.99, 19.99);
    return ((1 - y / (m * 12)) * 100).round();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _hasSubscription = prefs.getBool(_premiumKey) ?? false;
    _accessCodeUntil = DateTime.tryParse(
      prefs.getString(_accessUntilKey) ?? '',
    );
    notifyListeners();

    try {
      final iap = InAppPurchase.instance;
      storeAvailable = await iap.isAvailable();
      if (!storeAvailable) return;

      _purchaseSub = iap.purchaseStream.listen(
        _onPurchasesUpdated,
        onError: (Object e) => _setError('Purchase failed: $e'),
      );

      final response = await iap.queryProductDetails(kPremiumProductIds);
      plans = _selectPlans(response.productDetails);

      await _syncWithStore();
    } catch (e) {
      // No store (e.g. emulator without Play, or tests): keep cached state.
      storeAvailable = false;
      debugPrint('PremiumService: store unavailable: $e');
    }
    notifyListeners();
  }

  Map<String, SelectedPlan> _selectPlans(List<ProductDetails> details) {
    final offersById = <String, List<PlanOffer>>{};
    for (final d in details) {
      offersById.putIfAbsent(d.id, () => []).add(_toPlanOffer(d));
    }
    return {for (final e in offersById.entries) e.key: ?selectPlan(e.value)};
  }

  PlanOffer _toPlanOffer(ProductDetails d) {
    if (d is GooglePlayProductDetails && d.subscriptionIndex != null) {
      final offer =
          d.productDetails.subscriptionOfferDetails![d.subscriptionIndex!];
      return PlanOffer(
        productId: d.id,
        offerId: offer.offerId,
        source: d,
        phases: [
          for (final p in offer.pricingPhases)
            OfferPhase(
              priceMicros: p.priceAmountMicros,
              formattedPrice: p.formattedPrice,
              billingPeriod: p.billingPeriod,
              billingCycleCount: p.billingCycleCount,
            ),
        ],
      );
    }
    return PlanOffer(
      productId: d.id,
      offerId: null,
      source: d,
      phases: [
        OfferPhase(
          priceMicros: (d.rawPrice * 1000000).round(),
          formattedPrice: d.price,
          billingPeriod: '',
        ),
      ],
    );
  }

  /// Asks Google Play which subscriptions the user currently owns.
  Future<void> _syncWithStore() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final android = InAppPurchase.instance
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final result = await android.queryPastPurchases();
    if (result.error != null) return; // Couldn't check; keep cached state.

    final owned = result.pastPurchases.any(
      (p) =>
          kPremiumProductIds.contains(p.productID) &&
          p.status != PurchaseStatus.error &&
          p.status != PurchaseStatus.pending,
    );
    await _setSubscription(owned);

    for (final p in result.pastPurchases) {
      if (p.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(p);
      }
    }
  }

  Future<bool> buy(String productId) async {
    lastError = null;
    // The selected offer (free trial if eligible, else the base plan).
    final product = plans[productId]?.offer.source as ProductDetails?;
    if (!storeAvailable || product == null) {
      _setError(
        'Subscriptions are not available right now. '
        'Check your connection and Google Play account.',
      );
      return false;
    }

    purchasePending = true;
    notifyListeners();
    try {
      // Subscriptions are bought with buyNonConsumable.
      return await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      purchasePending = false;
      _setError('Purchase failed: $e');
      return false;
    }
  }

  Future<void> restore() async {
    lastError = null;
    if (!storeAvailable) {
      _setError('Google Play is not available right now.');
      return;
    }
    await InAppPurchase.instance.restorePurchases();
    await _syncWithStore();
  }

  Future<void> _onPurchasesUpdated(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (!kPremiumProductIds.contains(p.productID)) continue;

      switch (p.status) {
        case PurchaseStatus.pending:
          purchasePending = true;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // TODO: verify p.verificationData on a server (e.g. a Firebase
          // Function) before granting, to prevent spoofed purchases.
          purchasePending = false;
          await _setSubscription(true);
        case PurchaseStatus.error:
          purchasePending = false;
          _setError(p.error?.message ?? 'Purchase failed.');
        case PurchaseStatus.canceled:
          purchasePending = false;
      }

      if (p.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(p);
      }
    }
    notifyListeners();
  }

  Future<void> _setSubscription(bool value) async {
    _hasSubscription = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, value);
    notifyListeners();
  }

  void _setError(String message) {
    lastError = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}
