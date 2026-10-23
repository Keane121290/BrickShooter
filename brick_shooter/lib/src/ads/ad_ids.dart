import 'package:flutter/foundation.dart';

class AdIds {
  /// Live AdMob units. Keep this false in store builds.
  static const useTestAds = false;

  static const _androidRewarded = 'ca-app-pub-3790932559169878/2272614508';
  static const _iosRewarded = 'ca-app-pub-3790932559169878/8868058420';

  static const androidAppId = 'ca-app-pub-3790932559169878~5899289318';
  static const iosAppId = 'ca-app-pub-3790932559169878~8782182536';

  static const _androidTestRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const _iosTestRewarded = 'ca-app-pub-3940256099942544/1712485313';

  static String get rewardedUnitId {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (useTestAds) {
      return ios ? _iosTestRewarded : _androidTestRewarded;
    }
    return ios ? _iosRewarded : _androidRewarded;
  }

  static bool get supported {
    if (kIsWeb || const bool.fromEnvironment('FLUTTER_TEST')) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
