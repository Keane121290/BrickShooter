// lib/src/game/components/board_grid.dart
import 'dart:ui' as ui;
import 'package:flame/components.dart';

class BoardGrid extends PositionComponent {
  final int lanes;
  final double laneWidth;
  final double top;
  final double bottom;
  final ui.Color lineColor;
  final double lineWidth;

  BoardGrid({
    required this.lanes,
    required this.laneWidth,
    required this.top,
    required this.bottom,
    required this.lineColor,
    required this.lineWidth,
  }) {
    position = Vector2(0, 0);
    size = Vector2(laneWidth * lanes, bottom);
    priority = -700;
  }

  @override
  void render(ui.Canvas canvas) {
    final p = ui.Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth;

    // Vertical lines are transparent
    final verticalPaint = ui.Paint()
      ..color = const ui.Color(0x00000000) // Transparent
      ..strokeWidth = lineWidth;

    for (int i = 1; i < lanes; i++) {
      final x = i * laneWidth;
      canvas.drawLine(ui.Offset(x, top), ui.Offset(x, bottom), verticalPaint);
    }
    canvas.drawLine(ui.Offset(0, top), ui.Offset(laneWidth * lanes, top), p);
    canvas.drawLine(ui.Offset(0, bottom), ui.Offset(laneWidth * lanes, bottom), p);
  }
}
