import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

enum PowerUp { extraTime, slowDown, panic }

class PlayerProfile extends ChangeNotifier {
  int extraTime = GameConfig.startingPowerUps;
  int slowDown = GameConfig.startingPowerUps;
  int panic = GameConfig.startingPowerUps;
  int emeralds = 0;
  int emeraldsThisRound = 0;
  List<int> topScores = [];
  String? dailyRewardDay;
  bool pendingDailyNotice = false;
  bool _claimingDaily = false;

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
    dailyRewardDay = prefs.getString('dailyRewardDay');
    await claimDailyReward();
    notifyListeners();
  }

  /// Grants one of each power-up the first time the app is opened on a calendar day.
  Future<void> claimDailyReward() async {
    final today = _todayKey();
    if (_claimingDaily || dailyRewardDay == today) return;
    _claimingDaily = true;
    extraTime += 1;
    slowDown += 1;
    panic += 1;
    dailyRewardDay = today;
    pendingDailyNotice = true;
    notifyListeners();
    try {
      await _save();
    } finally {
      _claimingDaily = false;
    }
  }

  static String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
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

  void grant(PowerUp kind) {
    _addPower(kind, 1);
    notifyListeners();
    _save();
  }

  static int emeraldCost(PowerUp kind) {
    switch (kind) {
      case PowerUp.extraTime:
        return 5;
      case PowerUp.slowDown:
        return 8;
      case PowerUp.panic:
        return 12;
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
    if (dailyRewardDay != null) {
      await prefs.setString('dailyRewardDay', dailyRewardDay!);
    }
    await prefs.setBool('profileReady', true);
  }
}
