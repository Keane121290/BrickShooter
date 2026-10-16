import 'package:flame/components.dart';
import '../config.dart';

class DifficultyController extends Component {
  double rowPxPerSec = 0;
  double bulletPxPerSec = 0;
  final double rowHeight;
  final int Function() getScore;
  bool _paused = false;

  DifficultyController({required this.rowHeight, required this.getScore});

  @override
  Future<void> onLoad() async {
    rowPxPerSec = GameConfig.rowSpeedStartRps * rowHeight;
    _syncBullet();
  }

  void setPaused(bool paused) {
    _paused = paused;
  }

  void _syncBullet() {
    final rps = (rowPxPerSec / rowHeight);
    final bulletRps = (GameConfig.bulletBaseRps > rps * GameConfig.bulletFactor)
        ? GameConfig.bulletBaseRps
        : rps * GameConfig.bulletFactor;
    bulletPxPerSec = bulletRps * rowHeight;
  }

  void resetToStartSpeed() {
    rowPxPerSec = GameConfig.rowSpeedStartRps * rowHeight;
    _syncBullet();
  }

  /// Drops the current row speed. Score-based acceleration continues from there.
  void slowByFraction(double fraction) {
    final rps = rowPxPerSec / rowHeight;
    final next = (rps * (1 - fraction)).clamp(
      GameConfig.rowSpeedFloorRps,
      GameConfig.rowSpeedMaxRps,
    );
    rowPxPerSec = next * rowHeight;
    _syncBullet();
  }

  @override
  void update(double dt) {
    // Don't increase speed when paused
    if (_paused) return;

    final rps = (rowPxPerSec / rowHeight).clamp(
      GameConfig.rowSpeedFloorRps,
      GameConfig.rowSpeedMaxRps,
    );
    final accel = GameConfig.rowAccelForScore(getScore());
    final next = (rps + accel * dt).clamp(
      GameConfig.rowSpeedFloorRps,
      GameConfig.rowSpeedMaxRps,
    );
    rowPxPerSec = next * rowHeight;
    _syncBullet();
  }
}
