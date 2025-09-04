import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'brick_box.dart';

/// Grønn brikke som flyr opp til en mål-Y og så trigger en handling.
class BrickBullet extends PositionComponent {
  final int lane;
  final double speed; // px/s (settes fra MyGame)
  final ui.Color color;
  final double targetY;
  final void Function() onArrive;

  // Min. visuell flytid for “snappy men merkbart” skudd
  static const double _minFlightSeconds = 0.07; // 70 ms

  double _elapsed = 0;

  BrickBullet({
    required this.lane,
    required double xCenter,
    required double bottomY,
    required this.speed,
    required Vector2 size, // (brickWidth, brickHeight)
    required this.color,
    required this.targetY,
    required this.onArrive,
  }) {
    this.size = size;
    anchor = Anchor.bottomCenter;
    position = Vector2(xCenter, bottomY);
  }

  @override
  Future<void> onLoad() async {
    add(
      BrickBox(color: color, radius: 18, borderWidth: 3)
        ..position = Vector2(-width / 2, -height)
        ..size = size.clone(),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    // Fly oppover
    final nextY = y - speed * dt;

    // Har vi nådd eller passert mål?
    if (nextY <= targetY) {
      // Sørg for at vi ikke "ankommer" før min. flytid er passert – føles bedre
      if (_elapsed < _minFlightSeconds) {
        // hold igjen litt på første frame(r) om nødvendig
        y = targetY + 1; // nesten framme, men vent neste frame
        return;
      }
      y = targetY;
      onArrive();
      removeFromParent();
      return;
    }

    y = nextY;
  }

  double get top => y - height;
  double get bottom => y;
}
