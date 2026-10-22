import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../game/player_profile.dart';
import '../game/reward_schedule.dart';

/// Local reminder. Monday 09:00 GMT, plus one nudge at 09:00 GMT on day 2.
class WeeklyRewardNotifications {
  static const message = 'Your weekly rewards is ready';
  static const _introId = 7101;
  static const _weeklyId = 7102;
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static var _ready = false;

  static bool get _supported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static Future<void> sync(PlayerProfile profile) async {
    if (!_supported) return;
    try {
      await _ensureReady();
      final now = profile.now();
      final claimed = profile.claimedRewardPeriod;
      final intro = RewardSchedule.introAlertAt(profile.installedAt, now);
      final introPeriod = intro == null
          ? null
          : RewardSchedule.currentPeriod(
              installedAt: profile.installedAt,
              now: intro,
            );
      if (intro != null && introPeriod != null && introPeriod != claimed) {
        await _schedule(_introId, intro, repeatingMonday: false);
      } else {
        await _plugin.cancel(_introId);
      }

      final weekly = RewardSchedule.nextWeeklyAlert(
        installedAt: profile.installedAt,
        now: now,
      );
      await _schedule(_weeklyId, weekly, repeatingMonday: true);
    } catch (error) {
      debugPrint('Weekly reward notification failed: $error');
    }
  }

  static Future<void> _ensureReady() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true);
    _ready = true;
  }

  static Future<void> _schedule(
    int id,
    DateTime when, {
    required bool repeatingMonday,
  }) {
    final utc = when.toUtc();
    final scheduled = tz.TZDateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
    );
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'weekly_reward',
        'Weekly reward',
        channelDescription:
            'Lets you know when the weekly power-up set is ready.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );
    return _plugin.zonedSchedule(
      id,
      'Brick Tapper',
      message,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: repeatingMonday
          ? DateTimeComponents.dayOfWeekAndTime
          : null,
    );
  }
}
