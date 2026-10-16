class GameConfig {
  static const lanes = 4;
  static const rowsCapacityOnScreen = 12;
  static const initialRows = 3;
  static const prebufferRows = 3;
  static const boardTop = 120.0;
  static const brickAspect = 2 / 3;

  static const rowSpeedStartRps = 1.8;
  static const rowSpeedMaxRps = 5.5;

  static const roundSeconds = 60.0;
  static const extraTimeSeconds = 15.0;
  static const slowDownFactor = 0.85;
  static const rowSpeedFloorRps = 0.9;
  static const startingPowerUps = 5;

  /// Økning i rader/sekund per sekund, så lenge poengsummen er innenfor grensen.
  static const rowAccelBands = <(int, double)>[
    (50, 0.07),
    (100, 0.06),
    (150, 0.04),
    (399, 0.03),
  ];
  static const rowAccelAfter = 0.02;

  static double rowAccelForScore(int score) {
    for (final band in rowAccelBands) {
      if (score <= band.$1) return band.$2;
    }
    return rowAccelAfter;
  }

  /// Hver n-te rad som faller er en rød spesialrad.
  static const specialRowEvery = 25;
  static const cottonCandySeconds = 3.0;

  static const bulletBaseRps = 65.0;
  static const bulletFactor = 4.0;


}
