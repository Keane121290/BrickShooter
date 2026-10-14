import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/effects.dart';          // ScaleEffect, EffectController
import 'package:flutter/animation.dart';      // Curves
import '../config.dart';
import 'brick_box.dart';

class FallingRow extends PositionComponent {
  final int lanes;
  final double laneWidth;
  final double rowHeight;
  final double pad;                 // margin rundt hver brikke
  ui.Color color;
  ui.Color restingColor;
  final double Function() getSpeed; // global px/s fra spillet

  /// 1 er den nederste raden ved start. 0 betyr en rad som spilleren har bygget.
  int rowNumber = 0;

  bool get isSpecial =>
      rowNumber > 0 && rowNumber % GameConfig.specialRowEvery == 0;

  double get brickHeight => rowHeight - 2 * pad;
  double get brickWidth  => laneWidth  - 2 * pad;

  /// y = bunn av brikkene (anchor=bottomLeft)
  double bottomY = 0;

  /// Hvilke lanes som allerede er fylt (0..lanes-1)
  final Set<int> filledLanes;

  /// Lanes som er reservert av kuler i lufta (hindrer “racing”)
  final Set<int> reservedLanes = {};

  /// Når raden blir full settes denne; ryddes KUN når raden er nederst
  bool pendingClear = false;
  
  /// Animasjon for når raden skal "droppe" nedover
  bool _isDropping = false;
  bool get isDropping => _isDropping;

  FallingRow({
    required this.lanes,
    required this.laneWidth,
    required this.rowHeight,
    required this.pad,
    required this.color,
    required this.getSpeed,
    required this.bottomY,
    required Set<int> filledLanes,
  }) : filledLanes = Set<int>.from(filledLanes),
       restingColor = color {
    anchor = Anchor.bottomLeft;
    position = Vector2(0, bottomY);
    size = Vector2(laneWidth * lanes, rowHeight);
    priority = 20; // rad-komponenten selv
  }

  @override
  Future<void> onLoad() async {
    for (final lane in filledLanes) {
      _addBrick(lane, pop: false);
    }
  }

  final Map<BrickBox, double> _restX = {};

  void recolor(ui.Color next) {
    color = next;
    for (final box in children.whereType<BrickBox>()) {
      box.color = next;
    }
  }

  /// Liten sideveis sjangling. Hver kloss husker sitt opprinnelige x.
  void applySway(double clock) {
    var i = 0;
    for (final box in children.whereType<BrickBox>()) {
      final rest = _restX.putIfAbsent(box, () => box.position.x);
      final phase = i * 1.15 + rowNumber * 0.45;
      box.position.x = rest + sin(clock * 2 * pi * 1.7 + phase) * 8.0;
      i++;
    }
  }

  void clearSway() {
    for (final entry in _restX.entries) {
      if (entry.key.isMounted) {
        entry.key.position.x = entry.value;
      }
    }
    _restX.clear();
  }

  void rebuildBricks() {
    clearSway();
    for (final child in children.whereType<BrickBox>().toList()) {
      child.removeFromParent();
    }
    for (final lane in filledLanes) {
      _addBrick(lane, pop: false);
    }
  }

  BrickBox _addBrick(int lane, {required bool pop}) {
    final box = BrickBox(color: color, radius: 18, borderWidth: 3)
      ..position = Vector2(lane * laneWidth + pad, -brickHeight)
      ..size = Vector2(brickWidth, brickHeight)
      ..priority = 2;
    add(box);
    if (pop) {
      box.scale = Vector2.all(0.82);
      box.add(
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.085, curve: Curves.easeOutBack),
        ),
      );
    }
    return box;
  }

  /// Midten av klossen (eller hullet) i [lane], i verdenskoordinater.
  Vector2 brickCenter(int lane) {
    return absolutePositionOf(
      Vector2(
        lane * laneWidth + pad + brickWidth / 2,
        -brickHeight / 2,
      ),
    );
  }

  bool hasFreeLane(int lane) =>
      !filledLanes.contains(lane) && !reservedLanes.contains(lane);

  /// Reservér lane før skudd (ingen visuell ghost lenger)
  bool reserveLane(int lane, {ui.Color? ghostColor}) {
    if (!hasFreeLane(lane)) return false;
    reservedLanes.add(lane);
    return true;
  }

  /// Av-reservér (f.eks. ved kansellert kule)
  void unreserveLane(int lane) {
    reservedLanes.remove(lane);
  }

  /// Fyll lane; fjerner reservasjon og legger inn ekte brikke med “pop”.
  /// Returnerer `true` hvis raden ble full.
  bool fillLane(int lane) {
    reservedLanes.remove(lane);

    if (filledLanes.contains(lane)) {
      return filledLanes.length == lanes;
    }
    filledLanes.add(lane);
    _addBrick(lane, pop: true);
    return filledLanes.length == lanes;
  }

  /// Start en "drop" animasjon nedover
  void animateDrop(double targetY, {double duration = 0.2}) {
    if (_isDropping) return; // Allerede animerer
    
    _isDropping = true;
    final targetPosition = Vector2(position.x, targetY);
    
    add(
      MoveEffect.to(
        targetPosition,
        EffectController(
          duration: duration,
          curve: Curves.easeOut,
        ),
        onComplete: () {
          _isDropping = false;
          bottomY = y; // Oppdater bottomY etter animasjonen
        },
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Beveg deg nedover basert på hastighet fra getSpeed()
    // Dette fungerer både for normal bevegelse og drop-animasjon
    // (drop-animasjonen setter hastighet via getEffectiveSpeed() i RowController)
    final v = getSpeed();
    if (v > 0) {
      y += v * dt;
      bottomY = y;
    } else {
      // Oppdater bottomY hvis hastighet er 0
      bottomY = y;
    }
    
    // Hvis vi har en MoveEffect-animasjon (fra animateDrop), oppdater bottomY
    if (_isDropping) {
      bottomY = y;
    }
  }
}
