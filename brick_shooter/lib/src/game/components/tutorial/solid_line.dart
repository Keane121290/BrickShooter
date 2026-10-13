// lib/src/game/components/tutorial/solid_line.dart
import 'dart:ui' as ui;
import 'package:flame/components.dart';

/// Simple solid horizontal line
class SolidLine extends PositionComponent {
  final ui.Color color;
  final double thickness;
  double _opacity = 1.0;
  
  SolidLine({
    required Vector2 from,
    required Vector2 to,
    required this.color,
    this.thickness = 3,
    int priority = -100,
  }) {
    position = from;
    size = Vector2(to.x - from.x, thickness);
    this.priority = priority;
    anchor = Anchor.topLeft;
    _opacity = 0.0; // Start invisible for fade-in
  }

  void setOpacity(double opacity) {
    _opacity = opacity.clamp(0.0, 1.0);
  }

  @override
  void render(ui.Canvas canvas) {
    final paint = ui.Paint()
      ..color = color.withValues(alpha: _opacity)
      ..style = ui.PaintingStyle.fill;
    canvas.drawRect(size.toRect(), paint);
  }
}

