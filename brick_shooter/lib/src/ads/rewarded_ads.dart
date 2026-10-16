import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'ios_ad_consent.dart';

class RewardedPowerAds extends ChangeNotifier {
  RewardedAd? _ad;
  var _initialized = false;
  Future<void>? _initializing;

  Future<void> initialize() {
    if (_initialized || !AdIds.supported) return Future<void>.value();
    return _initializing ??= _initialize().whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initialize() async {
    try {
      // Consent is requested the first time the app reaches this point.
      // UMP shows its form only when it is still required.
      if (!await IosAdConsent.instance.ensureReady()) return;
      if (!await IosAdConsent.instance.adsAllowed()) return;
      await MobileAds.instance.initialize();
      _initialized = true;
      await _load();
    } catch (error) {
      debugPrint('Rewarded ads initialization failed: $error');
      _initialized = false;
    }
  }

  bool get isReady => _ad != null;

  void _keep(RewardedAd? ad) {
    final wasReady = _ad != null;
    _ad = ad;
    if (wasReady != (ad != null)) notifyListeners();
  }

  Future<bool> show({VoidCallback? onShown}) async {
    if (!AdIds.supported) return false;
    if (!_initialized) await initialize();
    if (!_initialized) return false;
    if (!await IosAdConsent.instance.adsAllowed()) {
      return false;
    }
    final ready = _ad ?? await _load();
    if (ready == null) return false;
    _keep(null);

    final earned = Completer<bool>();
    ready.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => onShown?.call(),
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!earned.isCompleted) earned.complete(false);
        unawaited(_load());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!earned.isCompleted) earned.complete(false);
        unawaited(_load());
      },
    );
    await ready.show(
      onUserEarnedReward: (ad, reward) {
        if (!earned.isCompleted) earned.complete(true);
      },
    );
    return earned.future;
  }

  var _retries = 0;

  Future<RewardedAd?> _load() async {
    if (!_initialized) return null;
    if (!await IosAdConsent.instance.adsAllowed()) {
      return null;
    }
    final done = Completer<RewardedAd?>();
    await RewardedAd.load(
      adUnitId: AdIds.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _keep(ad);
          _retries = 0;
          if (!done.isCompleted) done.complete(ad);
        },
        onAdFailedToLoad: (error) {
          _keep(null);
          debugPrint('Rewarded ad failed to load: ${error.message}');
          if (!done.isCompleted) done.complete(null);
          _retryLater();
        },
      ),
    );
    return done.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        _retryLater();
        return null;
      },
    );
  }

  void _retryLater() {
    if (_retries >= 4 || _ad != null) return;
    _retries++;
    Future<void>.delayed(const Duration(seconds: 6), () {
      if (_ad == null && _initialized) unawaited(_load());
    });
  }
}
