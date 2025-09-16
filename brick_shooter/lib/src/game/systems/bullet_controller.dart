import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';

class BulletController extends Component with HasGameRef<FlameGame> {
  final double floorY;
  final double laneWidth;
  final double Function() bulletPxPerSec;

  bool _paused = false;

  BulletController({
    required this.floorY,
    required this.laneWidth,
    required this.bulletPxPerSec,
  });

  final List<_Bullet> bullets = [];

  void shoot({
    required int lane,
    required double Function() targetYResolver,
    required Vector2 brickSize,
    required ui.Color color,
    required void Function() onArrive,
    required void Function() onCancel,
  }) {
    final xCenter = lane * laneWidth + laneWidth / 2;
    final bullet = _Bullet(
      x: xCenter,
      y: floorY,
      w: brickSize.x,
      h: brickSize.y,
      color: color,
      targetYResolver: targetYResolver,
      onArrive: onArrive,
      onCancel: onCancel,
    );
    bullets.add(bullet);
    gameRef.add(bullet);
  }

  void cancelHigherInLane(int lane, double bottomY) {
    for (final b in List<_Bullet>.from(bullets)) {
      if ((b.x - (lane * laneWidth + laneWidth / 2)).abs() < 1 &&
          b.y < bottomY) {
        b.cancel();
      }
    }
  }

  void setPaused(bool v) {
    _paused = v;
  }

  @override
  void update(double dt) {
    if (_paused) return;
    final speed = bulletPxPerSec(); // kontrolleres av DifficultyController
    for (final b in List<_Bullet>.from(bullets)) {
      b.y -= speed * dt;
      b.position = Vector2(b.x, b.y);
      if (b.y <= b.targetYResolver()) {
        b.arrive();
      }
    }
  }
}

class _Bullet extends PositionComponent {
  final double x;
  double y;
  final double w, h;
  final ui.Color color;
  final double Function() targetYResolver;
  final void Function() onArrive;
  final void Function() onCancel;
  bool _done = false;

  _Bullet({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.color,
    required this.targetYResolver,
    required this.onArrive,
    required this.onCancel,
  }) {
    size = Vector2(w, h);
    anchor = Anchor.center;
    position = Vector2(x, y);
    priority = 200;
  }

  void arrive() {
    if (_done) return;
    _done = true;
    removeFromParent();
    onArrive();
  }

  void cancel() {
    if (_done) return;
    _done = true;
    removeFromParent();
    onCancel();
  }

  @override
  void render(ui.Canvas canvas) {
    final paint = ui.Paint()..color = color;
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        size.toRect(),
        const ui.Radius.circular(6),
      ),
      paint,
    );
  }
}
