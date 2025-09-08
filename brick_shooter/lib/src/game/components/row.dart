// lib/src/game/components/row.dart
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/effects.dart';          // 👈 ScaleEffect, EffectController
import 'package:flutter/animation.dart';      // 👈 Curves
import 'brick_box.dart';

class FallingRow extends PositionComponent {
  final int lanes;
  final double laneWidth;
  final double rowHeight;
  final double pad;
  final ui.Color color;
  final double Function() getSpeed;

  double get brickHeight => rowHeight - 2 * pad;
  double get brickWidth => laneWidth - 2 * pad;

  double bottomY = 0;

  final Set<int> filledLanes;
  final Set<int> reservedLanes = {};
  final Map<int, BrickBox> _ghosts = {};
  bool pendingClear = false;

  FallingRow({
    required this.lanes,
    required this.laneWidth,
    required this.rowHeight,
    required this.pad,
    required this.color,
    required this.getSpeed,
    required this.bottomY,
    required Set<int> filledLanes,
  }) : filledLanes = Set<int>.from(filledLanes) {
    anchor = Anchor.bottomLeft;
    position = Vector2(0, bottomY);
    size = Vector2(laneWidth * lanes, rowHeight);
    priority = 20;
  }

  @override
  Future<void> onLoad() async {
    final h = brickHeight;
    final w = brickWidth;
    final top = -h;

    for (final lane in filledLanes) {
      final x = lane * laneWidth + pad;
      add(BrickBox(color: color, radius: 18, borderWidth: 3)
        ..position = Vector2(x, top)
        ..size = Vector2(w, h),
      );
    }
  }

  bool hasFreeLane(int lane) {
    return !filledLanes.contains(lane) && !reservedLanes.contains(lane);
  }

  bool reserveLane(int lane, {ui.Color? ghostColor}) {
    if (!hasFreeLane(lane)) return false;
    reservedLanes.add(lane);

    final h = brickHeight;
    final w = brickWidth;
    final top = -h;
    final x = lane * laneWidth + pad;

    final ghost = BrickBox(
      color: (ghostColor ?? color).withOpacity(0.45),
      radius: 18,
      borderWidth: 2,
    )
      ..position = Vector2(x, top)
      ..size = Vector2(w, h);

    _ghosts[lane] = ghost;
    add(ghost);
    return true;
  }

  void unreserveLane(int lane) {
    reservedLanes.remove(lane);
    final g = _ghosts.remove(lane);
    g?.removeFromParent();
  }

  bool fillLane(int lane) {
    reservedLanes.remove(lane);
    final g = _ghosts.remove(lane);
    g?.removeFromParent();

    if (filledLanes.contains(lane)) return filledLanes.length == lanes;
    filledLanes.add(lane);

    final h = brickHeight;
    final w = brickWidth;
    final top = -h;
    final x = lane * laneWidth + pad;

    final box = BrickBox(color: color, radius: 18, borderWidth: 3)
      ..position = Vector2(x, top)
      ..size = Vector2(w, h);

    add(box);

    // 👇 Impact-pop
    box.scale = Vector2.all(0.82);
    box.add(
      ScaleEffect.to(
        Vector2.all(1.0),
        EffectController(duration: 0.085, curve: Curves.easeOutBack),
      ),
    );

    return filledLanes.length == lanes;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final v = getSpeed();
    y += v * dt;
    bottomY = y;
  }
}
