import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import '../components/brick_box.dart';

class BulletController extends Component with HasGameReference<FlameGame> {
  final double floorY;
  final double laneWidth;
  final double Function() bulletPxPerSec;

  bool _paused = false;

  BulletController({
    required this.floorY,
    required this.laneWidth,
    required this.bulletPxPerSec,
  });

  final List<_Bullet> _bullets = [];

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
    _bullets.add(bullet);
    game.add(bullet);
  }

  void cancelHigherInLane(int lane, double bottomY) {
    for (final b in List<_Bullet>.from(_bullets)) {
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
    for (final b in List<_Bullet>.from(_bullets)) {
      b.y -= speed * dt;
      b.position = Vector2(b.x, b.y);
      
      // Stop when bullet center reaches or passes target bottomY
      // Since bullet moves upward (y decreases), we check when y <= targetY
      if (b.y <= b.targetYResolver()) {
        b.arrive();
      }
    }
  }
}

class _Bullet extends PositionComponent {
  @override
  final double x;
  @override
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
  Future<void> onLoad() async {
    // Bruk samme BrickBox som de blå blokkene for identisk størrelse og rendering
    // _Bullet bruker anchor = Anchor.center, så BrickBox må posisjoneres relativt til sentrum
    // w er brickWidth (bredde), h er brickHeight (høyde) - samme som blokkene i radene
    // BrickBox bruker anchor = Anchor.topLeft, så vi må posisjonere den slik at den er sentrert
    // For å sentrere: offset by half width to the left and half height up from center
    add(BrickBox(color: color, radius: 18, borderWidth: 3)
      ..anchor = Anchor.topLeft
      ..position = Vector2(-w / 2, -h / 2)
      ..size = Vector2(w, h) // w = brickWidth, h = brickHeight (samme som blokkene)
      ..priority = 2,
    );
  }
}
