import 'dart:ui' as ui;
import 'package:flame/components.dart';

class Shooter extends PositionComponent {
  final int lanes;
  final double laneWidth;
  @override
  final double y;
  @override
  final double width;
  @override
  final double height;

  Shooter({
    required this.lanes,
    required this.laneWidth,
    required this.y,
    required this.width,
    required this.height,
  }) {
    position = Vector2(0, y - height);
    size = Vector2(width, height);
    anchor = Anchor.topLeft;
  }

  @override
  Future<void> onLoad() async {
    // Bakplate
    add(
      RectangleComponent(
        position: Vector2.zero(),
        size: size.clone(),
        paint: ui.Paint()..color = const ui.Color(0xFF141821),
      ),
    );

    // Visuelle lane-divider
    for (int i = 1; i < lanes; i++) {
      final x = i * laneWidth;
      add(
        RectangleComponent(
          position: Vector2(x - 1, 0),
          size: Vector2(2, size.y),
          paint: ui.Paint()..color = const ui.Color(0xFF1F2632),
        ),
      );
    }
  }
}
