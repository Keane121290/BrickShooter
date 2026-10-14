import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

class TimerDisplay extends PositionComponent {
  double timeRemaining;
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
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: fontSize,
        fontWeight: ui.FontWeight.bold,
      ),
    );
    paragraphBuilder.addText(_formatTime(timeRemaining));
    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: double.infinity));
    size.setValues(paragraph.maxIntrinsicWidth, fontSize);
  }

  String _formatTime(double seconds) {
    final minutes = seconds ~/ 60;
    final secs = (seconds % 60).floor();
    return '${minutes.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  ui.Color _displayColor() {
    if (timeRemaining >= 10) return textColor;
    final tick = timeRemaining.floor();
    final progress = (1 - (timeRemaining - tick)).clamp(0.0, 1.0);
    final redAmount = tick.isEven ? progress : 1 - progress;
    return ui.Color.lerp(
      const ui.Color(0xFFFFFFFF),
      const ui.Color(0xFFFF3B30),
      redAmount,
    )!;
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    _updateSize();

    final urgent = timeRemaining < 10;
    final tick = timeRemaining.floor();
    final progress = urgent ? (1 - (timeRemaining - tick)).clamp(0.0, 1.0) : 0.0;
    final pulse = urgent ? 1 + 0.16 * math.sin(progress * math.pi) : 1.0;

    canvas.save();
    canvas.translate(size.x, 0);
    canvas.scale(pulse);
    canvas.translate(-size.x, 0);

    final textPaint = TextPaint(
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: _displayColor(),
      ),
    );
    textPaint.render(
      canvas,
      _formatTime(timeRemaining),
      Vector2.zero(),
      anchor: Anchor.topLeft,
    );
    canvas.restore();
  }
}
