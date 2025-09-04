import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import '../my_game.dart';

class Player extends PositionComponent with CollisionCallbacks, HasGameRef<MyGame> {
  final double floorY;

  double vy = 0;
  final double gravity = 2000; // px/s^2
  final double jumpImpulse = -980; // px/s
  bool _grounded = true;

  late final RectangleHitbox hitbox;

  Player({required this.floorY}) {
    size = Vector2(140, 140);
    anchor = Anchor.bottomCenter;
  }

  @override
  Future<void> onLoad() async {
    add(
      RectangleComponent(
        size: size.clone(),
        anchor: Anchor.bottomCenter,
        position: Vector2.zero(),
        paint: ui.Paint()..color = const ui.Color(0xFF53D769),
      ),
    );

    hitbox = RectangleHitbox();
    add(hitbox);

    position.y = floorY;
  }

  @override
  void update(double dt) {
    super.update(dt);
    vy += gravity * dt;
    y += vy * dt;

    if (y >= floorY) {
      y = floorY;
      vy = 0;
      _grounded = true;
    }
  }

  void handleTap() {
    if (_grounded) {
      vy = jumpImpulse;
      _grounded = false;
    }
  }

  void resetToFloor() {
    vy = 0;
    _grounded = true;
    position.y = floorY;
  }
}
