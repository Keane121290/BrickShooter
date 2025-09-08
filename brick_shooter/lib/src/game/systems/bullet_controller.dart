import 'dart:ui' as ui;
import 'package:flame/components.dart';
import '../components/bullet.dart';

class BulletController extends Component {
  final List<BrickBullet> bullets = [];

  final double floorY, laneWidth;
  final double Function() bulletPxPerSec;

  BulletController({
    required this.floorY,
    required this.laneWidth,
    required this.bulletPxPerSec,
  });

  /// Skyter en “brikke-kule” rett opp i `lane` til `targetYResolver()`.
  /// `onArrive` kalles ved landing; `onCancel` om kula kanselleres i lufta.
  void shoot({
    required int lane,
    required double Function() targetYResolver,
    required Vector2 brickSize,
    required ui.Color color,
    required void Function() onArrive,
    void Function()? onCancel,
  }) {
    final xCenter = lane * laneWidth + laneWidth / 2;
    final b = BrickBullet(
      lane: lane,
      xCenter: xCenter,
      bottomY: floorY - 8,
      speed: bulletPxPerSec(),
      size: brickSize,
      color: color,
      targetYResolver: targetYResolver,
      onArrive: onArrive,
      onCancel: onCancel,
    );
    bullets.add(b);
    add(b);
  }

  /// Kanseller alle kuler i `lane` som er på vei til et mål høyere enn `blockingBottomY`.
  void cancelHigherInLane(int lane, double blockingBottomY) {
    for (final b in List<BrickBullet>.from(bullets)) {
      if (!b.isMounted) continue;
      if (b.lane != lane) continue;
      final target = b.targetYResolver();
      if (target < blockingBottomY) {
        b.paused = true;
        b.removeFromParent();
      }
    }
  }
}
