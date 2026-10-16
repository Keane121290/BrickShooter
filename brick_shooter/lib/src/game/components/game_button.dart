// lib/src/game/components/game_button.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/events.dart';

enum ButtonType { pause, play, restart }

class GameButton extends PositionComponent with TapCallbacks {
  ButtonType buttonType; // Type knapp (mutable for pause/play toggle)
  final ui.Color backgroundColor;
  final ui.Color iconColor;
  final void Function() onTap;

  GameButton({
    required this.buttonType,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
    required double x,
    required double y,
    required double size,
  }) {
    position = Vector2(x, y);
    this.size = Vector2(size, size);
    anchor = Anchor.topLeft;
    priority = 1001; // Over poengsummen
  }

  @override
  bool onTapDown(TapDownEvent event) {
    onTap();
    return true;
  }

  @override
  void render(ui.Canvas canvas) {
    final rect = size.toRect();
    final center = ui.Offset(rect.center.dx, rect.center.dy);
    final radius = size.y / 2;

    // Drop shadow
    final shadowPaint = ui.Paint()
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4)
      ..color = ui.Color(0x40000000);
    canvas.save();
    canvas.translate(0, 2);
    canvas.drawCircle(center, radius, shadowPaint);
    canvas.restore();

    final iconPaint = ui.Paint()
      ..color = iconColor
      ..style = ui.PaintingStyle.fill
      ..strokeWidth = size.y * 0.12
      ..strokeCap = ui.StrokeCap.round;

    if (buttonType == ButtonType.pause) {
      _paintPause(canvas, center, radius, iconPaint);
      return;
    }

    // Runde bakgrunn med gradient
    final gradient = ui.Gradient.radial(
      center,
      radius,
      [
        backgroundColor.withValues(alpha: 0.3),
        backgroundColor.withValues(alpha: 0.15),
      ],
      const [0.0, 1.0],
    );
    final bgPaint = ui.Paint()..shader = gradient;
    canvas.drawCircle(center, radius, bgPaint);

    // Border
    final borderPaint = ui.Paint()
      ..color = backgroundColor
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius - 1.25, borderPaint);

    switch (buttonType) {
      case ButtonType.pause:
        break;
      case ButtonType.play:
        // Triangel for play
        final triangleSize = size.y * 0.35;
        final path = ui.Path();
        path.moveTo(center.dx - triangleSize * 0.2, center.dy - triangleSize / 2);
        path.lineTo(center.dx - triangleSize * 0.2, center.dy + triangleSize / 2);
        path.lineTo(center.dx + triangleSize * 0.6, center.dy);
        path.close();
        canvas.drawPath(path, iconPaint);
        break;

      case ButtonType.restart:
        // Sirkulær pil for restart - start fra øverst venstre, gå rundt mot høyre
        final arrowRadius = size.y * 0.22;
        final arrowCenter = ui.Offset(center.dx, center.dy);
        
        // Tegn sirkulær pil - start fra øverst venstre, gå nesten hele veien rundt
        iconPaint.style = ui.PaintingStyle.stroke;
        iconPaint.strokeWidth = size.y * 0.1;
        iconPaint.strokeCap = ui.StrokeCap.round;
        iconPaint.strokeJoin = ui.StrokeJoin.round;
        
        // Start vinkel: øverst venstre (ca. -135 grader eller -3π/4)
        final startAngle = -math.pi * 0.75;
        // Gå nesten hele veien rundt (ca. 270 grader eller 3π/2)
        final sweepAngle = math.pi * 1.5;
        final endAngle = startAngle + sweepAngle;
        
        // Tegn sirkelbue
        final arcRect = ui.Rect.fromCircle(center: arrowCenter, radius: arrowRadius);
        canvas.drawArc(
          arcRect,
          startAngle,
          sweepAngle,
          false,
          iconPaint,
        );
        
        // Pilspiss på slutten av buen - gjør den større og mer synlig
        final arrowHeadSize = size.y * 0.18; // Større pilspiss
        final arrowEndX = arrowCenter.dx + arrowRadius * math.cos(endAngle);
        final arrowEndY = arrowCenter.dy + arrowRadius * math.sin(endAngle);
        
        // Beregn tangent-retning (vinkelrett på radius ved endAngle)
        // Tangent er perpendikulær til radius, så vi roterer radius med 90 grader
        final tangentX = -math.sin(endAngle);
        final tangentY = math.cos(endAngle);
        
        // Radius-retning (fra sentrum til endepunkt)
        final radiusX = math.cos(endAngle);
        final radiusY = math.sin(endAngle);
        
        // Tegn pilspiss som en trekant som peker i tangent-retningen
        iconPaint.style = ui.PaintingStyle.fill;
        final headPath = ui.Path();
        
        // Spiss av pilen (litt utenfor sirkelen i tangent-retningen)
        final arrowTipX = arrowEndX + arrowHeadSize * 0.8 * tangentX;
        final arrowTipY = arrowEndY + arrowHeadSize * 0.8 * tangentY;
        
        // Base av pilspissen (på sirkelen, vinkelrett på tangent)
        final baseWidth = arrowHeadSize * 0.6;
        final baseX1 = arrowEndX - baseWidth * radiusX;
        final baseY1 = arrowEndY - baseWidth * radiusY;
        final baseX2 = arrowEndX + baseWidth * radiusX;
        final baseY2 = arrowEndY + baseWidth * radiusY;
        
        headPath.moveTo(arrowTipX, arrowTipY);
        headPath.lineTo(baseX1, baseY1);
        headPath.lineTo(baseX2, baseY2);
        headPath.close();
        canvas.drawPath(headPath, iconPaint);
        break;
    }
  }

  void _paintPause(
    ui.Canvas canvas,
    ui.Offset center,
    double radius,
    ui.Paint iconPaint,
  ) {
    canvas.drawCircle(
      center,
      radius + 2,
      ui.Paint()
        ..color = backgroundColor.withValues(alpha: 0.45)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7),
    );

    final edge = ui.Color.lerp(
      backgroundColor,
      const ui.Color(0xFF062033),
      0.45,
    )!;
    final highlight = ui.Color.lerp(
      const ui.Color(0xFFFFFFFF),
      backgroundColor,
      0.28,
    )!;
    canvas.drawCircle(
      center,
      radius,
      ui.Paint()
        ..shader = ui.Gradient.radial(
          center.translate(-radius * 0.18, -radius * 0.22),
          radius * 1.35,
          [highlight, backgroundColor, edge],
          const [0.0, 0.48, 1.0],
        ),
    );
    canvas.drawCircle(
      center,
      radius - 1.3,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = const ui.Color(0xF2FFFFFF),
    );
    canvas.drawCircle(
      center,
      radius * 0.78,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const ui.Color(0x66FFFFFF),
    );

    final barWidth = size.y * 0.13;
    final barHeight = size.y * 0.38;
    final gap = size.y * 0.1;
    final barY = center.dy - barHeight / 2;
    final radiusBar = ui.Radius.circular(barWidth / 2);
    for (final dx in [-gap / 2 - barWidth, gap / 2]) {
      final bar = ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(center.dx + dx, barY, barWidth, barHeight),
        radiusBar,
      );
      canvas.drawRRect(bar, iconPaint);
      canvas.drawRRect(
        bar,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const ui.Color(0x55FFFFFF),
      );
    }
  }
}

