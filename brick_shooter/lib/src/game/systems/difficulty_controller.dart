import 'package:flame/components.dart';
import '../config.dart';

class DifficultyController extends Component {
  double rowPxPerSec = 0;
  double bulletPxPerSec = 0;
  final double rowHeight;

  DifficultyController({required this.rowHeight});

  @override
  Future<void> onLoad() async {
    rowPxPerSec = GameConfig.rowSpeedStartRps * rowHeight;
    _syncBullet();
  }

  void _syncBullet() {
    final rps = (rowPxPerSec / rowHeight);
    final bulletRps =
    (GameConfig.bulletBaseRps > rps * GameConfig.bulletFactor)
        ? GameConfig.bulletBaseRps
        : rps * GameConfig.bulletFactor;
    bulletPxPerSec = bulletRps * rowHeight;
  }

  @override
  void update(double dt) {
    final rps = (rowPxPerSec / rowHeight)
        .clamp(GameConfig.rowSpeedStartRps, GameConfig.rowSpeedMaxRps);
    final next = (rps + GameConfig.rowAccelRpsPerS * dt)
        .clamp(GameConfig.rowSpeedStartRps, GameConfig.rowSpeedMaxRps);
    rowPxPerSec = next * rowHeight;
    _syncBullet();
  }
}
