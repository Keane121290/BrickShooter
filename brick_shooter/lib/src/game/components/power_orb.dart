import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../../ui/power_mark.dart';
import '../player_profile.dart';

class PowerOrb extends PositionComponent with TapCallbacks {
  PowerOrb({
    required this.kind,
    required this.color,
    required double diameter,
    required Vector2 center,
    required this.count,
    required this.shown,
    required this.explained,
    required this.caption,
    required this.urgency,
    required this.usable,
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
  final bool Function() explained;
  final String caption;
  final double Function() urgency;
  final bool Function() usable;
  final void Function() onPressed;

  double _clock = 0;
  double _explainScale = 1;

  @override
  void update(double dt) {
    super.update(dt);
    _clock += dt;
    final level = shown() ? urgency().clamp(0.0, 1.8) : 0.0;
    final wave = 0.5 + 0.5 * math.sin(_clock * (4.4 + level * 2.4));
    final attention = shown() && explained() && level <= 0
        ? 0.08 * (0.5 + 0.5 * math.sin(_clock * 3.6))
        : 0.0;
    final pulse = level <= 0 ? 1.0 + attention : 1.0 + level * 0.30 * wave;
    final explainTarget = shown() && explained() ? 1.45 : 1.0;
    _explainScale += (explainTarget - _explainScale) * (1 - math.exp(-dt * 10));
    scale = Vector2.all(pulse * _explainScale);
  }

  @override
  bool onTapDown(TapDownEvent event) {
    if (!shown() || !usable() || count() <= 0) return false;
    onPressed();
    return true;
  }

  @override
  void render(ui.Canvas canvas) {
    if (!shown()) return;
    final stock = count();
    final dim = stock <= 0 || !usable();
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

    if (dim) {
      canvas.saveLayer(
        ui.Rect.fromCircle(center: center, radius: radius),
        ui.Paint()..color = const ui.Color(0x88FFFFFF),
      );
    }
    paintPowerMark(
      canvas,
      ui.Rect.fromCenter(
        center: center,
        width: radius * 1.45,
        height: radius * 1.45,
      ),
      kind,
      const ui.Color(0xFFFFFFFF),
    );
    if (dim) canvas.restore();
    final label = TextPaint(
      style: TextStyle(
        color: dim ? const ui.Color(0x99FFFFFF) : color,
        fontSize: radius * 0.42,
        fontWeight: FontWeight.w800,
      ),
    );
    label.render(
      canvas,
      '${stock}x',
      Vector2(center.dx, center.dy + radius + 6),
      anchor: Anchor.topCenter,
    );
    if (!explained()) return;
    final captionPaint = TextPaint(
      style: TextStyle(
        color: color,
        fontSize: radius * 0.32,
        fontWeight: FontWeight.w800,
      ),
    );
    captionPaint.render(
      canvas,
      caption,
      Vector2(center.dx, center.dy - radius - 8),
      anchor: Anchor.bottomCenter,
    );
  }

}
