// lib/src/game/background.dart
import 'dart:ui' as ui;
import 'package:flame/components.dart';

class BackgroundScroller extends Component {
  final double width;
  final double height;
  final double floorY;

  bool _running = false;
  double _scroll = 0;

  BackgroundScroller({
    required this.width,
    required this.height,
    required this.floorY,
  });

  void setRunning(bool v) => _running = v;

  @override
  void render(ui.Canvas canvas) {
    final bg = ui.Paint()..color = const ui.Color(0xFF0F1115);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, width, height), bg);

    final gridPaint = ui.Paint()..color = const ui.Color(0x141FFFFFF);
    const gap = 24.0;
    for (double y = -(_scroll % gap); y < floorY; y += gap) {
      canvas.drawRect(ui.Rect.fromLTWH(0, y, width, 1.2), gridPaint);
    }

    final floorPaint = ui.Paint()..color = const ui.Color(0xFF2A2F3A);
    canvas.drawRect(ui.Rect.fromLTWH(0, floorY, width, height - floorY), floorPaint);
  }

  @override
  void update(double dt) {
    if (!_running) return;
    _scroll += 60 * dt;
  }
}
