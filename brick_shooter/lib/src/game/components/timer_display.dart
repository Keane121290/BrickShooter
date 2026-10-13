// lib/src/game/components/timer_display.dart
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

class TimerDisplay extends PositionComponent {
  double timeRemaining; // Sekunder
  final double fontSize;
  final ui.Color textColor;

  TimerDisplay({
    required this.timeRemaining,
    required this.fontSize,
    required this.textColor,
    required double x,
    required double y,
  }) {
    position = Vector2(x, y);
    anchor = Anchor.topLeft;
    priority = 1000;
    _updateSize();
  }

  void _updateSize() {
    final timeText = _formatTime(timeRemaining);
    final clockSize = fontSize * 0.6;
    final spacing = 8.0;
    
    // Bruk ParagraphBuilder for å måle tekstbredden
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: fontSize,
        fontWeight: ui.FontWeight.bold,
      ),
    );
    paragraphBuilder.addText(timeText);
    final paragraph = paragraphBuilder.build();
    paragraph.layout(ui.ParagraphConstraints(width: double.infinity));
    final textWidth = paragraph.maxIntrinsicWidth;
    
    size.setValues(clockSize + spacing + textWidth, fontSize);
  }

  String _formatTime(double seconds) {
    final minutes = seconds ~/ 60;
    final secs = (seconds % 60).floor();
    return '${minutes.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    
    // Oppdater størrelse hvis tiden har endret seg
    _updateSize();
    
    // Tegn klokkesymbol (enkel sirkel med visere)
    final clockSize = fontSize * 0.6;
    final clockCenter = Vector2(clockSize / 2, fontSize / 2);
    final clockRadius = clockSize / 2 - 2;
    
    // Sirkel for klokken
    final clockPaint = ui.Paint()
      ..color = textColor
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(clockCenter.toOffset(), clockRadius, clockPaint);
    
    // Visere (12 og 3 posisjoner)
    final handLength = clockRadius * 0.6;
    final handPaint = ui.Paint()
      ..color = textColor
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = ui.StrokeCap.round;
    
    // Kort viser (time hand) peker mot 12
    canvas.drawLine(
      clockCenter.toOffset(),
      clockCenter.toOffset() + Offset(0, -handLength * 0.5),
      handPaint,
    );
    
    // Lang viser (minute hand) peker mot 3
    canvas.drawLine(
      clockCenter.toOffset(),
      clockCenter.toOffset() + Offset(handLength * 0.7, 0),
      handPaint,
    );
    
    // Tegn tiden til høyre for klokkesymbolet
    final timeText = _formatTime(timeRemaining);
    final textPaint = TextPaint(
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
    
    final spacing = 8.0;
    final textX = clockSize + spacing;
    final textY = 0.0;
    
    textPaint.render(
      canvas,
      timeText,
      Vector2(textX, textY),
      anchor: Anchor.topLeft,
    );
  }
}

