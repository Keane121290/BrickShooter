// lib/src/game/components/shooter.dart
import 'dart:ui' as ui;
import 'package:flame/components.dart';

class Shooter extends PositionComponent {
  final int lanes;
  final double laneWidth;

  Shooter({
    required this.lanes,
    required this.laneWidth,
    required double y,
    required double width,
    required double height,
  }) {
    position = Vector2(0, y);
    size = Vector2(width, height);
    anchor = Anchor.topLeft;
    priority = 10;
  }

  @override
  void render(ui.Canvas canvas) {
    final base = ui.Paint()..color = const ui.Color(0xFF171A21);
    final glow = ui.Paint()..color = const ui.Color(0x2216FF88);
    final r = ui.RRect.fromRectAndRadius(size.toRect(), const ui.Radius.circular(24));
    canvas.drawRRect(r, base);
    canvas.drawRRect(r, glow);

    final hint = ui.Paint()..color = const ui.Color(0x3340FFAA);
    for (int i = 0; i < lanes; i++) {
      final cx = i * laneWidth + laneWidth / 2;
      canvas.drawLine(ui.Offset(cx, 6), ui.Offset(cx, size.y - 6), hint);
    }
  }
}
