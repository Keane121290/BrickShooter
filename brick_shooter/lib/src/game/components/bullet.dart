// lib/src/game/components/bullet.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'brick_box.dart';

class BrickBullet extends PositionComponent {
  final int lane;
  double speed; // px/s (kan settes til 0 på pause)
  final ui.Color color;
  final double Function() targetYResolver; // følger dynamisk mål (rad/toppspawn)
  final void Function() onArrive;
  final void Function()? onCancel;

  bool paused = false;
  bool _arrived = false;

  static const double _minFlightSeconds = 0.04; // snappier
  double _elapsed = 0;

  // Trail
  double _trailAcc = 0;

  BrickBullet({
    required this.lane,
    required double xCenter,
    required double bottomY,
    required this.speed,
    required Vector2 size,
    required this.color,
    required this.targetYResolver,
    required this.onArrive,
    this.onCancel,
  }) {
    this.size = size;
    anchor = Anchor.bottomCenter;
    position = Vector2(xCenter, bottomY);
    priority = 50;
  }

  @override
  Future<void> onLoad() async {
    add(BrickBox(color: color, radius: 18, borderWidth: 3)
      ..position = Vector2(-width / 2, -height)
      ..size = size.clone(),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (paused) return;

    _elapsed += dt;

    // enkel trail (små partikler)
    _trailAcc += dt;
    if (_trailAcc > 0.015) {
      _trailAcc = 0;
      final rnd = Random();
      parent?.add(
        ParticleSystemComponent(
          position: Vector2(x, y - height * 0.6),
          priority: 40,
          particle: Particle.generate(
            count: 4,
            lifespan: 0.18,
            generator: (i) => AcceleratedParticle(
              acceleration: Vector2(0, 500),
              speed: Vector2((rnd.nextDouble() - 0.5) * 50, -20 - rnd.nextDouble() * 40),
              child: CircleParticle(
                radius: 1.8,
                paint: ui.Paint()..color = color.withOpacity(0.8),
              ),
            ),
          ),
        ),
      );
    }

    final ty = targetYResolver();
    final nextY = y - speed * dt;
    if (nextY <= ty) {
      if (_elapsed < _minFlightSeconds) {
        y = ty + 1; // vent én frame til for visuell snap
        return;
      }
      y = ty;
      _arrived = true;
      onArrive();
      removeFromParent();
      return;
    }
    y = nextY;
  }

  @override
  void onRemove() {
    super.onRemove();
    // Om kula forsvinner uten å ha "avlevert" brikken (f.eks. gameover), si fra
    if (!_arrived && onCancel != null) {
      onCancel!();
    }
  }

  double get top => y - height;
  double get bottom => y;
}
