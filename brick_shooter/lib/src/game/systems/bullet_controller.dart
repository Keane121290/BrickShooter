import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import '../components/brick_box.dart';

class BulletController extends Component with HasGameReference<FlameGame> {
  final double floorY;
  final double Function() bulletPxPerSec;

  bool _paused = false;
  bool _candyActive = false;
  double _candyClock = 0;
  ui.Color Function(int lane) _candyColor = _defaultCandy;

  static ui.Color _defaultCandy(int lane) => const ui.Color(0xFFFF6EC7);

  BulletController({
    required this.floorY,
    required this.bulletPxPerSec,
  });

  final List<_Bullet> _bullets = [];

  void shoot({
    required int lane,
    required Vector2 Function() holeCenter,
    required Vector2 brickSize,
    required ui.Color color,
    required void Function() onArrive,
    required void Function() onCancel,
  }) {
    final bullet = _Bullet(
      lane: lane,
      x: holeCenter().x,
      y: floorY,
      w: brickSize.x,
      h: brickSize.y,
      color: color,
      holeCenter: holeCenter,
      onArrive: onArrive,
      onCancel: onCancel,
    );
    _bullets.add(bullet);
    game.add(bullet);
  }

  void cancelHigherInLane(int lane, double bottomY) {
    for (final b in List<_Bullet>.from(_bullets)) {
      if (b.lane == lane && b.y < bottomY) {
        b.cancel();
      }
    }
  }

  void syncCottonCandy({
    required bool active,
    required double clock,
    required ui.Color Function(int lane) colorForLane,
  }) {
    _candyActive = active;
    _candyClock = clock;
    _candyColor = colorForLane;
    for (final b in _bullets) {
      b.paint(active ? colorForLane(b.lane) : b.color);
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
      final nextY = b.y - speed * dt;
      final hole = b.holeCenter();
      final sway = _candyActive ? sin(_candyClock * 2 * pi * 1.7 + b.lane) * 8.0 : 0.0;
      if (nextY <= hole.y) {
        b.position = hole;
        b.arrive();
      } else {
        b.position = Vector2(hole.x + sway, nextY);
        b.paint(_candyActive ? _candyColor(b.lane) : b.color);
      }
    }
  }
}

class _Bullet extends PositionComponent {
  final int lane;
  final double w, h;
  final ui.Color color;
  final Vector2 Function() holeCenter;
  final void Function() onArrive;
  final void Function() onCancel;
  bool _done = false;

  _Bullet({
    required this.lane,
    required double x,
    required double y,
    required this.w,
    required this.h,
    required this.color,
    required this.holeCenter,
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

  void paint(ui.Color next) {
    for (final box in children.whereType<BrickBox>()) {
      box.color = next;
    }
  }

  @override
  Future<void> onLoad() async {
    // Samme BrickBox og samme mål som klossene i radene.
    // Forelderen har anker i sentrum, og lokal (0, 0) er øverst til venstre,
    // så klossen fyller skuddet og senteret treffer midt i hullet.
    add(BrickBox(color: color, radius: 18, borderWidth: 3)
      ..anchor = Anchor.topLeft
      ..position = Vector2.zero()
      ..size = Vector2(w, h)
      ..priority = 2,
    );
  }
}
