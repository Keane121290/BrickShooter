/// Weekly power-up reward.
///
/// A new install stays quiet on day one. The first set opens at 00:00 UTC on
/// the next calendar day and can be collected until the following Monday
/// 09:00 UTC. After that, one set opens every Monday at 09:00 UTC and stays
/// available through the week, including Sunday.
class RewardSchedule {
  static DateTime day2Start(DateTime installedUtc) {
    final utc = installedUtc.toUtc();
    return DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
    ).add(const Duration(days: 1));
  }

  /// Latest Monday 09:00 UTC that is not after [instant].
  static DateTime mondayNineAtOrBefore(DateTime instant) {
    final utc = instant.toUtc();
    final daysFromMonday = utc.weekday - DateTime.monday;
    final monday = DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
    ).subtract(Duration(days: daysFromMonday));
    var atNine = DateTime.utc(monday.year, monday.month, monday.day, 9);
    if (utc.isBefore(atNine)) {
      atNine = atNine.subtract(const Duration(days: 7));
    }
    return atNine;
  }

  /// First Monday 09:00 UTC after the introductory window.
  ///
  /// When day 2 itself is a Monday, that morning's 09:00 stays inside the
  /// introduction so the player is not offered two sets on the same date.
  static DateTime firstWeeklyMonday(DateTime firstUnlock) {
    final start = firstUnlock.toUtc();
    var candidate = mondayNineAtOrBefore(start).add(const Duration(days: 7));
    final sameDay =
        candidate.year == start.year &&
        candidate.month == start.month &&
        candidate.day == start.day;
    if (sameDay || !candidate.isAfter(start)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  /// Id of the set that can be collected at [now], or null on the install day.
  ///
  /// [installedAt] null means the profile already existed before weekly
  /// rewards, so the Monday schedule applies immediately.
  static String? currentPeriod({
    required DateTime? installedAt,
    required DateTime now,
  }) {
    final nowUtc = now.toUtc();
    if (installedAt == null) {
      return weekId(mondayNineAtOrBefore(nowUtc));
    }
    final first = day2Start(installedAt);
    if (nowUtc.isBefore(first)) return null;
    final weekly = firstWeeklyMonday(first);
    if (nowUtc.isBefore(weekly)) return 'intro:${first.toIso8601String()}';
    return weekId(mondayNineAtOrBefore(nowUtc));
  }

  static String weekId(DateTime mondayNine) =>
      'week:${mondayNine.toUtc().toIso8601String()}';

  /// 09:00 UTC on day 2, while that moment is still ahead.
  static DateTime? introAlertAt(DateTime? installedAt, DateTime now) {
    if (installedAt == null) return null;
    final first = day2Start(installedAt);
    final alert = DateTime.utc(first.year, first.month, first.day, 9);
    if (!alert.isAfter(now.toUtc())) return null;
    return alert;
  }

  /// Next Monday 09:00 UTC that should raise the weekly reminder.
  static DateTime nextWeeklyAlert({
    required DateTime? installedAt,
    required DateTime now,
  }) {
    final nowUtc = now.toUtc();
    final earliest = installedAt == null
        ? mondayNineAtOrBefore(nowUtc)
        : firstWeeklyMonday(day2Start(installedAt));
    var candidate = earliest;
    if (!candidate.isAfter(nowUtc)) {
      final last = mondayNineAtOrBefore(nowUtc);
      candidate = last.add(const Duration(days: 7));
    }
    if (candidate.isBefore(earliest)) return earliest;
    return candidate;
  }
}
