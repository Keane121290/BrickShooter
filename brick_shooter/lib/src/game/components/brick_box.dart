import 'dart:ui' as ui;
import 'package:flame/components.dart';

class BrickBox extends PositionComponent {
  final ui.Color color;
  final double radius;
  final double borderWidth;

  BrickBox({
    required this.color,
    this.radius = 18,
    this.borderWidth = 3,
  }) {
    anchor = Anchor.topLeft;
  }

  @override
  void render(ui.Canvas canvas) {
    // ytre rrect (skygge/kant)
    final rrect = ui.RRect.fromRectAndRadius(
      size.toRect(),
      ui.Radius.circular(radius),
    );

    // kant (litt mørkere)
    final borderPaint = ui.Paint()
      ..color = ui.Color.alphaBlend(const ui.Color(0xAA000000), color)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // fyll (lys gradient)
    final fillPaint = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(0, 0),
        ui.Offset(0, size.y),
        [
          ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.38)!,
          color,
        ],
      );

    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, borderPaint);
  }
}
