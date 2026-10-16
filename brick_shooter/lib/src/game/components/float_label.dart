import 'dart:ui' as ui;

import 'package:flame/components.dart';

/// A short label that rises and fades. Used for Slow-down and emeralds.
class FloatLabel extends PositionComponent {
  FloatLabel({
    required String text,
    required this.color,
    required Vector2 origin,
    this.fontSize = 28,
  }) : _text = text {
    position = origin.clone();
    anchor = Anchor.center;
    priority = 1200;
  }

  final String _text;
  final ui.Color color;
  final double fontSize;
  double _age = 0;
  static const _life = 0.9;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    position.y -= 52 * dt;
    if (_age >= _life) removeFromParent();
  }

  @override
  void render(ui.Canvas canvas) {
    final t = (_age / _life).clamp(0.0, 1.0);
    final alpha = (1 - t) * (1 - t);
    final scale = 1 + t * 0.22;
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: fontSize * scale,
        fontWeight: ui.FontWeight.w800,
        textAlign: ui.TextAlign.center,
      ),
    );
    builder.pushStyle(
      ui.TextStyle(
        color: color.withValues(alpha: alpha),
        shadows: [
          ui.Shadow(
            color: color.withValues(alpha: alpha * 0.65),
            blurRadius: 10,
          ),
        ],
      ),
    );
    builder.addText(_text);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 220));
    canvas.drawParagraph(
      paragraph,
      ui.Offset(-paragraph.maxIntrinsicWidth / 2, -fontSize),
    );
  }
}
