// lib/src/game/components/tutorial/finger_hint.dart
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// Emoji hint 👆 centered above the lane with tapping animation
class FingerHint extends TextComponent {
  final Vector2 basePosition;
  double _tapTime = 0.0;
  double _opacity = 0.0;
  
  FingerHint({required Vector2 center, int priority = 999})
      : basePosition = center,
        super(
    text: '👆',
    anchor: Anchor.center,
    position: center,
    priority: priority,
    textRenderer: TextPaint(
      style: const TextStyle(fontSize: 64), // Double the default size
    ),
  );

  @override
  void setOpacity(double opacity, {Object? paintId}) {
    _opacity = opacity.clamp(0.0, 1.0);
  }

  @override
  void render(ui.Canvas canvas) {
    if (_opacity <= 0.0) return; // Don't render if invisible
    
    // Apply opacity using saveLayer
    final bounds = ui.Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.saveLayer(bounds, ui.Paint()..color = ui.Color.fromRGBO(255, 255, 255, _opacity));
    super.render(canvas);
    canvas.restore();
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Tapping animation: press down, then lift.
    _tapTime += dt;
    final tapCycle = (_tapTime * 2.4) % 1.0;
    final pressed = tapCycle < 0.28 ? tapCycle / 0.28 : (1 - tapCycle) / 0.72;
    final tapOffset = (pressed.clamp(0.0, 1.0) as num).toDouble() * 18.0;
    final squash = 1 - (pressed.clamp(0.0, 1.0) as num).toDouble() * 0.14;
    position = Vector2(basePosition.x, basePosition.y + tapOffset);
    scale.setValues(squash, 1 + (1 - squash));
  }
}

