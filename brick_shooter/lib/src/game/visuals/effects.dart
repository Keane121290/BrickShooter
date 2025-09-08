import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/particles.dart';

void emitSquareBurst(Component parent, Vector2 pos, ui.Color color) {
  final rnd = Random();
  parent.add(
    ParticleSystemComponent(
      position: pos,
      priority: 60,
      particle: Particle.generate(
        count: 28,
        lifespan: 0.45,
        generator: (_) {
          final a = rnd.nextDouble() * 2 * pi;
          final r = 140 + rnd.nextDouble() * 120;
          final vx = cos(a) * r;
          final vy = sin(a) * r - 80;
          return AcceleratedParticle(
            acceleration: Vector2(0, 600),
            speed: Vector2(vx, vy),
            child: CircleParticle(
              radius: 2.2,
              paint: ui.Paint()..color = color.withOpacity(0.95),
            ),
          );
        },
      ),
    ),
  );
}
