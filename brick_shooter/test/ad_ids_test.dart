import 'package:brick_shooter/src/ads/ad_ids.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('store builds request the live rewarded units', () {
    expect(AdIds.useTestAds, isFalse);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      AdIds.rewardedUnitId,
      'ca-app-pub-3790932559169878/2272614508',
    );

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(
      AdIds.rewardedUnitId,
      'ca-app-pub-3790932559169878/8868058420',
    );
  });
}
