import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';

/// Glowing column over the lane the player should tap.
class LaneHighlight extends PositionComponent {
  LaneHighlight({
    required double x,
    required double width,
    required double top,
    required double height,
  }) {
    position = Vector2(x, top);
    size = Vector2(width, height);
    priority = 980;
  }

  double opacity = 0;
  double _time = 0;

  void setOpacity(double value) {
    opacity = value.clamp(0.0, 1.0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(ui.Canvas canvas) {
    if (opacity <= 0) return;
    final pulse = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(_time * 5.5));
    final rect = size.toRect().deflate(8);
    final radius = ui.Radius.circular(rect.width * 0.18);
    final body = ui.RRect.fromRectAndRadius(rect, radius);
    canvas.drawRRect(
      body,
      ui.Paint()..color = ui.Color.fromRGBO(125, 255, 154, opacity * 0.28 * pulse),
    );
    canvas.drawRRect(
      body,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = ui.Color.fromRGBO(255, 255, 255, opacity * 0.9 * pulse),
    );

    final ripple = (_time * 1.4) % 1.0;
    final ring = ui.Rect.fromCenter(
      center: ui.Offset(size.x / 2, size.y * 0.72),
      width: rect.width * (0.25 + ripple * 0.7),
      height: rect.width * (0.18 + ripple * 0.45),
    );
    canvas.drawOval(
      ring,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = ui.Color.fromRGBO(255, 255, 255, opacity * (1 - ripple) * 0.85),
    );
  }
}
