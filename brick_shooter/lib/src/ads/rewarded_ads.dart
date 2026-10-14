import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'ios_ad_consent.dart';

class RewardedPowerAds {
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
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          !await IosAdConsent.instance.ensureReady()) {
        return;
      }
      await MobileAds.instance.initialize();
      _initialized = true;
      await _load();
    } catch (error) {
      debugPrint('Rewarded ads initialization failed: $error');
      _initialized = false;
    }
  }

  Future<bool> show() async {
    if (!AdIds.supported) return false;
    if (!_initialized) await initialize();
    if (!_initialized) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        !await IosAdConsent.instance.canRequestAds()) {
      return false;
    }
    final ready = _ad ?? await _load();
    if (ready == null) return false;
    _ad = null;

    final earned = Completer<bool>();
    ready.fullScreenContentCallback = FullScreenContentCallback(
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

  Future<RewardedAd?> _load() async {
    if (!_initialized) return null;
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        !await IosAdConsent.instance.canRequestAds()) {
      return null;
    }
    final done = Completer<RewardedAd?>();
    await RewardedAd.load(
      adUnitId: AdIds.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          if (!done.isCompleted) done.complete(ad);
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          debugPrint('Rewarded ad failed to load: ${error.message}');
          if (!done.isCompleted) done.complete(null);
        },
      ),
    );
    return done.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => null,
    );
  }
}
