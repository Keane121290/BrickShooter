import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'ios_ad_consent.dart';

class RewardedPowerAds extends ChangeNotifier {
  RewardedAd? _ad;
  var _initialized = false;
  var _loading = false;
  var _foreground = true;
  var _retries = 0;
  Future<void>? _initializing;
  Future<RewardedAd?>? _inFlight;
  Timer? _retry;

  bool get isReady => _ad != null;

  /// True only while a load request is actually in flight.
  bool get isLoading => _loading;

  Future<void> initialize() {
    if (!AdIds.supported) return Future<void>.value();
    if (_initialized) {
      if (_ad == null) unawaited(_load());
      return Future<void>.value();
    }
    return _initializing ??= _initialize().whenComplete(() {
      _initializing = null;
    });
  }

  /// Called when the app returns to the foreground. A load started while the
  /// screen was off often fails with no Javascript engine, so try again.
  void onResume() {
    _foreground = true;
    if (!AdIds.supported) return;
    _retries = 0;
    _retry?.cancel();
    _retry = null;
    if (_initialized) {
      if (_ad == null) unawaited(_load());
    } else {
      unawaited(initialize());
    }
  }

  void onPause() {
    _foreground = false;
    _retry?.cancel();
    _retry = null;
  }

  Future<void> _initialize() async {
    try {
      // Consent is requested the first time the app reaches this point.
      // UMP shows its form only when it is still required.
      if (!await IosAdConsent.instance.ensureReady()) return;
      if (!await IosAdConsent.instance.adsAllowed()) return;
      await MobileAds.instance.initialize();
      _initialized = true;
      // Give WebView a moment to come up before the first request.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await _load();
    } catch (error) {
      debugPrint('Rewarded ads initialization failed: $error');
      _initialized = false;
    }
  }

  void _setLoading(bool value) {
    if (_loading == value) return;
    _loading = value;
    notifyListeners();
  }

  void _keep(RewardedAd? ad) {
    final wasReady = _ad != null;
    _ad = ad;
    if (ad != null) {
      _retries = 0;
      _retry?.cancel();
      _retry = null;
    }
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

  Future<RewardedAd?> _load() {
    if (_ad != null) return Future<RewardedAd?>.value(_ad);
    final current = _inFlight;
    if (current != null) return current;
    final run = _loadNew();
    _inFlight = run;
    return run.whenComplete(() {
      if (identical(_inFlight, run)) _inFlight = null;
    });
  }

  Future<RewardedAd?> _loadNew() async {
    if (!_initialized || !_foreground) return null;
    if (!await IosAdConsent.instance.adsAllowed()) return null;
    _setLoading(true);
    final done = Completer<RewardedAd?>();
    unawaited(
      RewardedAd.load(
        adUnitId: AdIds.rewardedUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _keep(ad);
            if (!done.isCompleted) done.complete(ad);
          },
          onAdFailedToLoad: (error) {
            debugPrint('Rewarded ad failed to load: ${error.message}');
            _keep(null);
            if (!done.isCompleted) done.complete(null);
          },
        ),
      ).catchError((Object error) {
        debugPrint('Rewarded ad failed to load: $error');
        if (!done.isCompleted) done.complete(null);
      }),
    );
    final ad = await done.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => null,
    );
    _setLoading(false);
    if (ad == null) _scheduleRetry();
    return ad;
  }

  void _scheduleRetry() {
    if (!_initialized || !_foreground || _ad != null || _retry != null) return;
    _retries++;
    final seconds = switch (_retries) {
      1 => 2,
      2 => 4,
      3 => 8,
      _ => 15,
    };
    _retry = Timer(Duration(seconds: seconds), () {
      _retry = null;
      if (_ad == null && _initialized && _foreground) unawaited(_load());
    });
  }
}
