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
    // Tapping animation: move up and down
    _tapTime += dt;
    final tapCycle = (_tapTime * 2.0) % 1.0; // 0.5 second cycle
    final tapOffset = (tapCycle < 0.5) 
        ? (tapCycle * 2.0) * 8.0  // Move down (0 to 8 pixels)
        : (1.0 - (tapCycle - 0.5) * 2.0) * 8.0; // Move back up (8 to 0 pixels)
    
    position = Vector2(basePosition.x, basePosition.y + tapOffset);
  }
}

