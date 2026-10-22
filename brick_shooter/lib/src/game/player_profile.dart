import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'reward_schedule.dart';

enum PowerUp { extraTime, slowDown, panic }

class PlayerProfile extends ChangeNotifier {
  int extraTime = GameConfig.startingPowerUps;
  int slowDown = GameConfig.startingPowerUps;
  int panic = GameConfig.startingPowerUps;
  int emeralds = 0;
  int emeraldsThisRound = 0;
  List<int> topScores = [];
  DateTime? installedAt;
  String? claimedRewardPeriod;
  bool pendingWeeklyNotice = false;
  bool vibrationEnabled = true;
  bool soundEnabled = true;
  bool _claimingReward = false;

  /// Clock for the weekly reward. Tests pin this; the app uses UTC now.
  DateTime Function() now = () => DateTime.now().toUtc();

  int countOf(PowerUp kind) {
    switch (kind) {
      case PowerUp.extraTime:
        return extraTime;
      case PowerUp.slowDown:
        return slowDown;
      case PowerUp.panic:
        return panic;
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ready = prefs.getBool('profileReady') ?? false;
    if (!ready) {
      extraTime = GameConfig.startingPowerUps;
      slowDown = GameConfig.startingPowerUps;
      panic = GameConfig.startingPowerUps;
      emeralds = 0;
      await prefs.setInt('powerExtra', extraTime);
      await prefs.setInt('powerSlow', slowDown);
      await prefs.setInt('powerPanic', panic);
      await prefs.setInt('emeralds', emeralds);
      await prefs.setBool('profileReady', true);
      installedAt = now().toUtc();
      await prefs.setString('installedAt', installedAt!.toIso8601String());
    } else {
      extraTime = prefs.getInt('powerExtra') ?? 0;
      slowDown = prefs.getInt('powerSlow') ?? 0;
      panic = prefs.getInt('powerPanic') ?? 0;
      emeralds = prefs.getInt('emeralds') ?? 0;
    }

    final stored = prefs.getString('topScores') ?? '';
    topScores = stored
        .split(',')
        .map((part) => int.tryParse(part) ?? 0)
        .where((value) => value > 0)
        .toList();
    final best = prefs.getInt('bestScore') ?? 0;
    if (best > 0 && !topScores.contains(best)) {
      _insertScore(best);
    }
    final installedRaw = prefs.getString('installedAt');
    if (installedAt == null && installedRaw != null) {
      installedAt = DateTime.tryParse(installedRaw)?.toUtc();
    }
    claimedRewardPeriod = prefs.getString('weeklyRewardPeriod');
    vibrationEnabled = prefs.getBool('vibrationOn') ?? true;
    soundEnabled = prefs.getBool('soundOn') ?? true;
    await claimWeeklyReward();
    notifyListeners();
  }

  /// Grants one of each power-up once for the open weekly period.
  ///
  /// Nothing is granted on the day the profile is created. From the next UTC
  /// day the set can be collected, and after that once each Monday 09:00 UTC
  /// week, through the following Sunday.
  Future<void> claimWeeklyReward() async {
    final period = RewardSchedule.currentPeriod(
      installedAt: installedAt,
      now: now(),
    );
    if (_claimingReward || period == null || claimedRewardPeriod == period) {
      return;
    }
    _claimingReward = true;
    extraTime += 1;
    slowDown += 1;
    panic += 1;
    claimedRewardPeriod = period;
    pendingWeeklyNotice = true;
    notifyListeners();
    try {
      await _save();
    } finally {
      _claimingReward = false;
    }
  }

  void beginRound() {
    emeraldsThisRound = 0;
    notifyListeners();
  }

  void addEmerald() {
    emeralds += 1;
    emeraldsThisRound += 1;
    notifyListeners();
    _save();
  }

  bool tryUse(PowerUp kind) {
    if (countOf(kind) <= 0) return false;
    switch (kind) {
      case PowerUp.extraTime:
        extraTime -= 1;
      case PowerUp.slowDown:
        slowDown -= 1;
      case PowerUp.panic:
        panic -= 1;
    }
    notifyListeners();
    _save();
    return true;
  }

  void grant(PowerUp kind, [int amount = 1]) {
    _addPower(kind, amount);
    notifyListeners();
    _save();
  }

  static int emeraldCost(PowerUp kind) {
    switch (kind) {
      case PowerUp.extraTime:
        return 10;
      case PowerUp.slowDown:
        return 5;
      case PowerUp.panic:
        return 15;
    }
  }

  /// How many of [kind] a rewarded ad adds.
  static int adRewardCount(PowerUp kind) {
    switch (kind) {
      case PowerUp.extraTime:
        return 3;
      case PowerUp.slowDown:
        return 4;
      case PowerUp.panic:
        return 2;
    }
  }

  bool buyWithEmeralds(PowerUp kind) {
    final cost = emeraldCost(kind);
    if (emeralds < cost) return false;
    emeralds -= cost;
    _addPower(kind, 1);
    notifyListeners();
    _save();
    return true;
  }

  void addEmeralds(int amount) {
    if (amount <= 0) return;
    emeralds += amount;
    notifyListeners();
    _save();
  }

  /// Turns this round's emeralds into [factor] times as many.
  void multiplyRoundEmeralds(int factor) {
    if (factor <= 1 || emeraldsThisRound <= 0) return;
    final bonus = emeraldsThisRound * (factor - 1);
    emeralds += bonus;
    emeraldsThisRound += bonus;
    notifyListeners();
    _save();
  }

  void _addPower(PowerUp kind, int amount) {
    switch (kind) {
      case PowerUp.extraTime:
        extraTime += amount;
      case PowerUp.slowDown:
        slowDown += amount;
      case PowerUp.panic:
        panic += amount;
    }
  }

  int submitScore(int value) {
    if (value <= 0) return 0;
    var better = 0;
    var ties = 0;
    for (final existing in topScores) {
      if (existing > value) better++;
      if (existing == value) ties++;
    }
    final place = better + ties + 1;
    _insertScore(value);
    notifyListeners();
    _save();
    return place <= 3 ? place : 0;
  }

  void toggleVibration() {
    vibrationEnabled = !vibrationEnabled;
    notifyListeners();
    _save();
  }

  void toggleSound() {
    soundEnabled = !soundEnabled;
    notifyListeners();
    _save();
  }

  void _insertScore(int value) {
    final next = [...topScores, value]..sort((a, b) => b.compareTo(a));
    topScores = next.take(3).toList();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('powerExtra', extraTime);
    await prefs.setInt('powerSlow', slowDown);
    await prefs.setInt('powerPanic', panic);
    await prefs.setInt('emeralds', emeralds);
    await prefs.setString('topScores', topScores.join(','));
    if (installedAt != null) {
      await prefs.setString('installedAt', installedAt!.toIso8601String());
    }
    if (claimedRewardPeriod != null) {
      await prefs.setString('weeklyRewardPeriod', claimedRewardPeriod!);
    }
    await prefs.setBool('profileReady', true);
    await prefs.setBool('vibrationOn', vibrationEnabled);
    await prefs.setBool('soundOn', soundEnabled);
  }
}
