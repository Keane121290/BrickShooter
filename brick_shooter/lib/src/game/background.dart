// lib/src/game/background.dart
import 'dart:ui' as ui;
import 'package:flame/components.dart';

class BackgroundScroller extends PositionComponent {
  @override
  final double width;
  @override
  final double height;
  final double floorY;

  BackgroundScroller({
    required this.width,
    required this.height,
    required this.floorY,
  }) {
    size = Vector2(width, height);
    position = Vector2.zero();
    anchor = Anchor.topLeft;
  }

  void setRunning(bool v) {
    // No-op: background is now static
  }

  @override
  void render(ui.Canvas canvas) {
    final sky = ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(0, 0),
        ui.Offset(0, height),
        const [
          ui.Color(0xFF070B16),
          ui.Color(0xFF12182C),
          ui.Color(0xFF1A2744),
          ui.Color(0xFF24304A),
        ],
        const [0.0, 0.42, 0.78, 1.0],
      );
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, width, height), sky);

    // Soft light down each lane, so the board reads without a hard grid.
    final lane = width / 4;
    for (var i = 0; i < 4; i++) {
      final left = i * lane;
      canvas.drawRect(
        ui.Rect.fromLTWH(left, 0, lane, height),
        ui.Paint()
          ..shader = ui.Gradient.linear(
            ui.Offset(left, 0),
            ui.Offset(left + lane, 0),
            [
              const ui.Color(0x00000000),
              ui.Color(i.isEven ? 0x123C6A9A : 0x102E5680),
              const ui.Color(0x00000000),
            ],
            const [0.0, 0.5, 1.0],
          ),
      );
    }

    final horizon = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(0, floorY - 90),
        ui.Offset(0, floorY + 20),
        const [
          ui.Color(0x00000000),
          ui.Color(0x334A7CFF),
          ui.Color(0x00000000),
        ],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(ui.Rect.fromLTWH(0, floorY - 90, width, 120), horizon);

    final star = ui.Paint()..color = const ui.Color(0x66FFFFFF);
    const stars = <ui.Offset>[
      ui.Offset(0.12, 0.08),
      ui.Offset(0.28, 0.16),
      ui.Offset(0.47, 0.06),
      ui.Offset(0.63, 0.14),
      ui.Offset(0.81, 0.09),
      ui.Offset(0.18, 0.24),
      ui.Offset(0.72, 0.22),
      ui.Offset(0.90, 0.18),
    ];
    for (final point in stars) {
      canvas.drawCircle(ui.Offset(point.dx * width, point.dy * height), 1.3, star);
    }
  }

  @override
  void update(double dt) {
    // Background is static, no update needed
  }
}
