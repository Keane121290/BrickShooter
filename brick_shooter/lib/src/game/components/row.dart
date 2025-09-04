import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'brick_box.dart';

class FallingRow extends PositionComponent {
  // Generelt
  final int lanes;
  final double laneWidth;
  final double rowHeight;
  final double pad;              // lik margin på alle kanter av brikkene
  final ui.Color color;

  /// Global speed-funksjon levert fra spillet (px/s)
  final double Function() getSpeed;

  // Geometri for kollisjon
  double get brickHeight => rowHeight - 2 * pad;
  double bottomY = 0; // denne komponentens "y" = bunn av brikkene (anchor=bottomLeft)

  // Modus A: gap-rad (vanlig bånd)
  final int? gapLane;

  // Modus B: custom-fylte lanes (spiller-generert rad)
  Set<int>? filledLanes; // muterbar slik at vi kan fylle inn flere lanes

  bool get isGapRow => gapLane != null;

  // ---- Konstruktører ----
  FallingRow._internal({
    required this.lanes,
    required this.laneWidth,
    required this.rowHeight,
    required this.pad,
    required this.getSpeed,
    required this.color,
    required this.bottomY,
    required this.gapLane,
    required this.filledLanes,
  }) {
    // Viktig: forenkler kollisjon – radens "y" *er* bunn av brikkene
    anchor = Anchor.bottomLeft;
    position = Vector2(0, bottomY);
    size = Vector2(laneWidth * lanes, rowHeight);
  }

  factory FallingRow.gapRow({
    required int lanes,
    required double laneWidth,
    required double rowHeight,
    required double pad,
    required double bottomY,
    required double Function() getSpeed, // <—
    required ui.Color color,
    required int gapLane,
  }) {
    assert(gapLane >= 0 && gapLane < lanes);
    return FallingRow._internal(
      lanes: lanes,
      laneWidth: laneWidth,
      rowHeight: rowHeight,
      pad: pad,
      getSpeed: getSpeed,
      color: color,
      bottomY: bottomY,
      gapLane: gapLane,
      filledLanes: null,
    );
  }

  factory FallingRow.customRow({
    required int lanes,
    required double laneWidth,
    required double rowHeight,
    required double pad,
    required double bottomY,
    required double Function() getSpeed, // <—
    required ui.Color color,
    required Set<int> filledLanes,
  }) {
    assert(filledLanes.every((l) => l >= 0 && l < lanes));
    return FallingRow._internal(
      lanes: lanes,
      laneWidth: laneWidth,
      rowHeight: rowHeight,
      pad: pad,
      getSpeed: getSpeed,
      color: color,
      bottomY: bottomY,
      gapLane: null,
      filledLanes: Set<int>.from(filledLanes),
    );
  }

  @override
  Future<void> onLoad() async {
    final double w = laneWidth - 2 * pad;   // brikkebredde
    final double h = brickHeight;           // brikkehøyde
    final double top = -h;                  // anchor = bottomLeft

    if (isGapRow) {
      for (int lane = 0; lane < lanes; lane++) {
        if (lane == gapLane) continue;
        final double x = lane * laneWidth + pad;
        add(
          BrickBox(color: color, radius: 18, borderWidth: 3)
            ..position = Vector2(x, top)
            ..size = Vector2(w, h),
        );
      }
    } else {
      for (final lane in filledLanes!) {
        final double x = lane * laneWidth + pad;
        add(
          BrickBox(color: color, radius: 18, borderWidth: 3)
            ..position = Vector2(x, top)
            ..size = Vector2(w, h),
        );
      }
    }
  }

  /// Fyller inn en lane i en **custom** spiller–rad (ingen effekt for gap-rad).
  void fillLane(int lane) {
    if (isGapRow) return;
    if (lane < 0 || lane >= lanes) return;
    if (filledLanes!.contains(lane)) return;

    filledLanes!.add(lane);

    final double w = laneWidth - 2 * pad;
    final double h = brickHeight;
    final double top = -h;
    final double x = lane * laneWidth + pad;

    add(
      BrickBox(color: color, radius: 18, borderWidth: 3)
        ..position = Vector2(x, top)
        ..size = Vector2(w, h),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    final double v = getSpeed(); // <- les **global** fart hver frame
    y += v * dt;                 // nedover
    bottomY = y;                 // hold kollisjons-hjelper i sync
  }
}
