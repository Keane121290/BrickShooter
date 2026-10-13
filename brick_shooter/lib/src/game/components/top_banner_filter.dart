// lib/src/game/components/top_banner_filter.dart
import 'dart:ui' as ui;
import 'package:flame/components.dart';

class TopBannerFilter extends PositionComponent {
  @override
  final double width;
  @override
  final double height;

  TopBannerFilter({
    required this.width,
    required this.height,
  }) {
    size = Vector2(width, height);
    position = Vector2.zero();
    anchor = Anchor.topLeft;
    priority = 999; // Over bakgrunnen, under poengsummen (1000)
  }

  @override
  void render(ui.Canvas canvas) {
    // Mørkt gradient som fades nedover
    final gradient = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(0, 0),
        ui.Offset(0, height),
        [
          const ui.Color(0xE0000000), // Mørk øverst (88% opacity)
          const ui.Color(0x80000000), // Medium mørk (50% opacity)
          const ui.Color(0x00000000), // Transparent nederst
        ],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, width, height), gradient);
  }
}







