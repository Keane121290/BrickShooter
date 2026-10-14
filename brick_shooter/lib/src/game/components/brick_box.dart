// lib/src/game/components/brick_box.dart
import 'dart:ui' as ui;
import 'package:flame/components.dart';

class BrickBox extends PositionComponent {
  ui.Color color;
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
    final rect = size.toRect();
    final rrect = ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(radius));

    // Soft drop shadow
    final shadowPaint = ui.Paint()
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6)
      ..color = ui.Color(0x80000000);
    canvas.save();
    canvas.translate(0, 2);
    canvas.drawRRect(rrect, shadowPaint);
    canvas.restore();

    // Inner gradient (mørkere, mindre hvit blending)
    final grad = ui.Gradient.linear(
      ui.Offset(rect.left, rect.top),
      ui.Offset(rect.left, rect.bottom),
      [
        ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.2)!, // Redusert fra 0.45 til 0.2
        color,
        ui.Color.lerp(color, const ui.Color(0xFF00334D), 0.25)!,
      ],
      const [0.0, 0.6, 1.0],
    );
    final fill = ui.Paint()..shader = grad;
    canvas.drawRRect(rrect, fill);

    // Border / glow
    final border = ui.Paint()
      ..color = ui.Color.alphaBlend(const ui.Color(0x3300FFFF), color)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRRect(rrect, border);

    // Gloss highlight (redusert for mindre hvit)
    final gloss = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(rect.left, rect.top),
        ui.Offset(rect.left, rect.top + rect.height * .35), // Redusert område
        [
          ui.Color.lerp(const ui.Color(0xFFFFFFFF), color, 0.6)!, // Mer farge, mindre hvit
          ui.Color.lerp(const ui.Color(0xFFFFFFFF), color, 0.85)!,
          ui.Color.lerp(const ui.Color(0xFFFFFFFF), color, 1.0)!,
        ],
        const [0.0, 0.6, 1.0],
      )
      ..blendMode = ui.BlendMode.plus
      ..style = ui.PaintingStyle.fill;
    final glossRect = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(rect.left + 2, rect.top + 2, rect.width - 4, rect.height * .32), // Mindre område
      ui.Radius.circular(radius * .8),
    );
    canvas.drawRRect(glossRect, gloss);
  }
}
