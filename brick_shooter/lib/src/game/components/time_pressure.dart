import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// Large countdown shown in the middle of the board when under 10 seconds.
class TimePressure extends PositionComponent {
  TimePressure({
    required this.secondsLeft,
    required this.visible,
    required this.fontSize,
  }) {
    anchor = Anchor.center;
    priority = 1100;
  }

  final double Function() secondsLeft;
  final bool Function() visible;
  final double fontSize;

  double _clock = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _clock += dt;
    final wave = 0.5 + 0.5 * math.sin(_clock * 5.2);
    scale = Vector2.all(visible() ? 0.92 + wave * 0.14 : 1);
  }

  @override
  void render(ui.Canvas canvas) {
    if (!visible()) return;
    final seconds = secondsLeft().ceil().clamp(1, 10);
    final wave = 0.5 + 0.5 * math.sin(_clock * 5.2);
    final alpha = 0.55 + wave * 0.32;
    final glow = ui.Paint()
      ..color = ui.Color.fromRGBO(255, 70, 90, alpha * 0.35)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 18);
    canvas.drawCircle(ui.Offset.zero, fontSize * 0.72, glow);

    final paint = TextPaint(
      style: TextStyle(
        color: ui.Color.fromRGBO(255, 64, 84, alpha),
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        height: 1,
        shadows: [
          Shadow(color: ui.Color.fromRGBO(80, 0, 16, alpha), blurRadius: 12),
        ],
      ),
    );
    paint.render(canvas, '$seconds', Vector2.zero(), anchor: Anchor.center);
  }
}
