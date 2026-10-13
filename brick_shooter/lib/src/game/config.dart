class GameConfig {
  static const lanes = 4;
  static const rowsCapacityOnScreen = 12;
  static const initialRows = 3;
  static const prebufferRows = 3;
  static const boardTop = 120.0;
  static const brickAspect = 2 / 3;

  static const rowSpeedStartRps = 2.0;
  static const rowSpeedMaxRps = 5.5;
  static const rowAccelRpsPerS = 0.1; // Increased to make speed increase faster

  static const bulletBaseRps = 65.0;
  static const bulletFactor = 4.0;


}
