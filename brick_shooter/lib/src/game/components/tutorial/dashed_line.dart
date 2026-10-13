// lib/src/game/components/tutorial/dashed_line.dart
import 'dart:ui' as ui;
import 'package:flame/components.dart';

/// Dashed vertical line for tutorial hint
class DashedLine extends PositionComponent {
  final ui.Color color;
  final double dash;
  final double gap;
  final double lineWidth;
  double _opacity = 1.0;
  
  DashedLine({
    required double x,
    required double yTop,
    required double yBottom,
    required this.color,
    this.dash = 10,
    this.gap = 6,
    this.lineWidth = 3.0, // Thicker line for clarity
    int priority = 999,
  }) {
    position = Vector2(x, yTop);
    size = Vector2(lineWidth, yBottom - yTop);
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
    double y = 0;
    while (y < size.y) {
      final h = (y + dash <= size.y) ? dash : (size.y - y);
      canvas.drawRect(ui.Rect.fromLTWH(0, y, size.x, h), paint);
      y += dash + gap;
    }
  }
}

