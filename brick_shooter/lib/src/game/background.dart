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
    // Draw smooth gradient background (darker teal-blue at top, lighter vibrant teal-blue at bottom)
    final gradient = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(0, 0),
        ui.Offset(0, height),
        [
          const ui.Color(0xFF152028), // Very dark teal-blue at top
          const ui.Color(0xFF1E3A4A), // Medium dark teal-blue
          const ui.Color(0xFF2A5566), // Lighter vibrant teal-blue at bottom
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, width, height), gradient);

    // Draw clean static grid (approximately 10 columns x 30 rows)
    const gridColumns = 10;
    const gridRows = 30;
    
    final cellWidth = width / gridColumns;
    final cellHeight = height / gridRows;
    
    // Subtle grid lines with very low opacity for a clean look
    final gridPaint = ui.Paint()
      ..color = const ui.Color(0x15FFFFFF) // Very subtle white
      ..strokeWidth = 0.5 // Thin lines
      ..style = ui.PaintingStyle.stroke
      ..isAntiAlias = true; // Smooth rendering 

    // Draw vertical grid lines
    for (int i = 0; i <= gridColumns; i++) {
      final x = i * cellWidth;
      canvas.drawLine(
        ui.Offset(x, 0),
        ui.Offset(x, height),
        gridPaint,
      );
    }

    // Draw horizontal grid lines
    for (int i = 0; i <= gridRows; i++) {
      final y = i * cellHeight;
      canvas.drawLine(
        ui.Offset(0, y),
        ui.Offset(width, y),
        gridPaint,
      );
    }
  }

  @override
  void update(double dt) {
    // Background is static, no update needed
  }
}
