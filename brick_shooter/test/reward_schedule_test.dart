import 'package:brick_shooter/src/game/config.dart';
import 'package:brick_shooter/src/game/hud_inset.dart';
import 'package:brick_shooter/src/game/player_profile.dart';
import 'package:brick_shooter/src/game/reward_schedule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('hud clears a notch and keeps the old margin otherwise', () {
    expect(playHudTop(0), 24);
    expect(playHudTop(12), 24);
    expect(playHudTop(59), 67);
  });

  test('power-up prices and ad rewards', () {
    expect(PlayerProfile.emeraldCost(PowerUp.extraTime), 10);
    expect(PlayerProfile.emeraldCost(PowerUp.slowDown), 5);
    expect(PlayerProfile.emeraldCost(PowerUp.panic), 15);
    expect(PlayerProfile.adRewardCount(PowerUp.extraTime), 3);
    expect(PlayerProfile.adRewardCount(PowerUp.slowDown), 4);
    expect(PlayerProfile.adRewardCount(PowerUp.panic), 2);
  });

  test('install day stays quiet and day 2 opens a single set', () async {
    SharedPreferences.setMockInitialValues({});
    final installed = _atWeekday(DateTime.wednesday, hour: 15);
    final profile = PlayerProfile()..now = () => installed;
    await profile.load();

    expect(profile.extraTime, GameConfig.startingPowerUps);
    expect(profile.pendingWeeklyNotice, isFalse);

    profile.now = () => installed.add(const Duration(hours: 5));
    await profile.claimWeeklyReward();
    expect(profile.extraTime, GameConfig.startingPowerUps);

    final day2 = RewardSchedule.day2Start(installed)
        .add(const Duration(minutes: 5));
    profile.now = () => day2;
    await profile.claimWeeklyReward();
    expect(profile.extraTime, GameConfig.startingPowerUps + 1);
    expect(profile.slowDown, GameConfig.startingPowerUps + 1);
    expect(profile.panic, GameConfig.startingPowerUps + 1);
    expect(profile.pendingWeeklyNotice, isTrue);

    profile.pendingWeeklyNotice = false;
    final mondayNine = RewardSchedule.firstWeeklyMonday(
      RewardSchedule.day2Start(installed),
    );
    final sundayBefore = mondayNine.subtract(const Duration(hours: 15));
    expect(sundayBefore.weekday, DateTime.sunday);
    profile.now = () => sundayBefore;
    await profile.claimWeeklyReward();
    expect(profile.extraTime, GameConfig.startingPowerUps + 1);

    profile.now = () => mondayNine;
    await profile.claimWeeklyReward();
    expect(profile.extraTime, GameConfig.startingPowerUps + 2);
    expect(profile.pendingWeeklyNotice, isTrue);
  });

  test('a Monday install does not grant twice on day 2', () async {
    SharedPreferences.setMockInitialValues({});
    final installed = _atWeekday(DateTime.monday, hour: 8);
    final profile = PlayerProfile()..now = () => installed;
    await profile.load();
    expect(profile.extraTime, GameConfig.startingPowerUps);

    profile.now = () =>
        DateTime.utc(installed.year, installed.month, installed.day, 9);
    await profile.claimWeeklyReward();
    expect(profile.extraTime, GameConfig.startingPowerUps);

    final day2 = RewardSchedule.day2Start(installed).add(
      const Duration(hours: 2),
    );
    profile.now = () => day2;
    await profile.claimWeeklyReward();
    expect(profile.extraTime, GameConfig.startingPowerUps + 1);

    final laterThatDay = DateTime.utc(day2.year, day2.month, day2.day, 20);
    profile.now = () => laterThatDay;
    await profile.claimWeeklyReward();
    expect(profile.extraTime, GameConfig.startingPowerUps + 1);
  });

  test('an existing profile can collect through Sunday, once', () async {
    SharedPreferences.setMockInitialValues({
      'profileReady': true,
      'powerExtra': 1,
      'powerSlow': 1,
      'powerPanic': 1,
    });
    final sunday = _atWeekday(DateTime.sunday, hour: 16);
    final profile = PlayerProfile()..now = () => sunday;
    await profile.load();

    expect(profile.installedAt, isNull);
    expect(profile.extraTime, 2);
    expect(profile.pendingWeeklyNotice, isTrue);

    profile.pendingWeeklyNotice = false;
    profile.now = () => sunday.add(const Duration(hours: 3));
    await profile.claimWeeklyReward();
    expect(profile.extraTime, 2);

    final nextMonday = RewardSchedule.mondayNineAtOrBefore(sunday)
        .add(const Duration(days: 7));
    profile.now = () => nextMonday.subtract(const Duration(hours: 1));
    await profile.claimWeeklyReward();
    expect(profile.extraTime, 2);

    profile.now = () => nextMonday;
    await profile.claimWeeklyReward();
    expect(profile.extraTime, 3);
    expect(profile.pendingWeeklyNotice, isTrue);
  });

  test('the weekly reminder lands on a later Monday at 09:00 UTC', () {
    final installed = _atWeekday(DateTime.wednesday, hour: 15);
    final next = RewardSchedule.nextWeeklyAlert(
      installedAt: installed,
      now: installed,
    );
    expect(next.weekday, DateTime.monday);
    expect(next.hour, 9);
    expect(next.isAfter(RewardSchedule.day2Start(installed)), isTrue);

    final after = next.add(const Duration(hours: 2));
    final following = RewardSchedule.nextWeeklyAlert(
      installedAt: installed,
      now: after,
    );
    expect(following, next.add(const Duration(days: 7)));
  });
}

DateTime _atWeekday(int weekday, {required int hour}) {
  var day = DateTime.utc(2026, 6, 1, hour);
  while (day.weekday != weekday) {
    day = day.add(const Duration(days: 1));
  }
  return day;
}
