import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../player_profile.dart';

class PowerOrb extends PositionComponent with TapCallbacks {
  PowerOrb({
    required this.kind,
    required this.color,
    required double diameter,
    required Vector2 center,
    required this.count,
    required this.shown,
    required this.urgency,
    required this.onPressed,
  }) {
    size = Vector2.all(diameter);
    anchor = Anchor.center;
    position = center;
    priority = 1002;
  }

  final PowerUp kind;
  final ui.Color color;
  final int Function() count;
  final bool Function() shown;
  final double Function() urgency;
  final void Function() onPressed;

  double _clock = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _clock += dt;
    final level = shown() ? urgency().clamp(0.0, 1.4) : 0.0;
    final wave = 0.5 + 0.5 * math.sin(_clock * 5.2);
    final pulse = level <= 0 ? 1.0 : 1.0 + level * 0.22 * wave;
    scale = Vector2.all(pulse);
  }

  @override
  bool onTapDown(TapDownEvent event) {
    if (!shown() || count() <= 0) return false;
    onPressed();
    return true;
  }

  @override
  void render(ui.Canvas canvas) {
    if (!shown()) return;
    final stock = count();
    final dim = stock <= 0;
    final center = size.toRect().center;
    final radius = size.x / 2;

    final shadow = ui.Paint()
      ..color = const ui.Color(0x66000000)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
    canvas.drawCircle(center.translate(0, 2), radius, shadow);

    final fill = ui.Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          color.withValues(alpha: dim ? 0.28 : 0.95),
          ui.Color.lerp(color, const ui.Color(0xFF101820), 0.45)!
              .withValues(alpha: dim ? 0.4 : 1),
        ],
      );
    canvas.drawCircle(center, radius, fill);

    final ring = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = dim ? const ui.Color(0x66FFFFFF) : const ui.Color(0xFFFFFFFF);
    canvas.drawCircle(center, radius - 1.4, ring);

    _drawIcon(canvas, center, radius * 0.42, dim);
    final label = TextPaint(
      style: TextStyle(
        color: dim ? const ui.Color(0x99FFFFFF) : const ui.Color(0xFFFFFFFF),
        fontSize: radius * 0.48,
        fontWeight: FontWeight.w800,
      ),
    );
    label.render(
      canvas,
      '$stock',
      Vector2(center.dx, center.dy + radius * 0.48),
      anchor: Anchor.center,
    );
  }

  void _drawIcon(ui.Canvas canvas, ui.Offset center, double reach, bool dim) {
    final paint = ui.Paint()
      ..color = dim ? const ui.Color(0xCCFFFFFF) : const ui.Color(0xFFFFFFFF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = reach * 0.28
      ..strokeCap = ui.StrokeCap.round;
    final iconCenter = center.translate(0, -reach * 0.35);
    switch (kind) {
      case PowerUp.extraTime:
        canvas.drawLine(
          iconCenter.translate(-reach, 0),
          iconCenter.translate(reach, 0),
          paint,
        );
        canvas.drawLine(
          iconCenter.translate(0, -reach),
          iconCenter.translate(0, reach),
          paint,
        );
      case PowerUp.slowDown:
        canvas.drawLine(
          iconCenter.translate(-reach, -reach * 0.45),
          iconCenter.translate(reach * 0.2, -reach * 0.45),
          paint,
        );
        canvas.drawLine(
          iconCenter.translate(-reach * 0.55, reach * 0.45),
          iconCenter.translate(reach, reach * 0.45),
          paint,
        );
      case PowerUp.panic:
        paint.style = ui.PaintingStyle.fill;
        canvas.drawCircle(iconCenter.translate(0, -reach * 0.15), reach * 0.22, paint);
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromCenter(
              center: iconCenter.translate(0, reach * 0.55),
              width: reach * 0.38,
              height: reach * 0.9,
            ),
            ui.Radius.circular(reach),
          ),
          paint,
        );
    }
  }
}
