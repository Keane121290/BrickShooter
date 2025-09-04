import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'brick_box.dart';

class BottomRow extends PositionComponent {
  final int lanes;
  final double laneWidth;
  final double rowHeight;
  final double rowVerticalGap;
  final double laneInnerPadding;
  final double yBottom;
  final double width;
  final ui.Color color;
  final Set<int> filledLanes;

  double get blockAreaHeight => rowHeight - rowVerticalGap;

  BottomRow({
    required this.lanes,
    required this.laneWidth,
    required this.rowHeight,
    required this.rowVerticalGap,
    required this.laneInnerPadding,
    required this.yBottom,
    required this.width,
    required this.color,
    required this.filledLanes,
  }) {
    position = Vector2(0, yBottom);
    size = Vector2(width, rowHeight);
    anchor = Anchor.topLeft;
  }

  @override
  Future<void> onLoad() async {
    final topOffset = -blockAreaHeight;
    for (int lane = 0; lane < lanes; lane++) {
      if (!filledLanes.contains(lane)) continue;
      final x = lane * laneWidth + laneInnerPadding / 2;
      final w = laneWidth - laneInnerPadding;

      final brick = BrickBox(color: color, radius: 18, borderWidth: 3)
        ..position = Vector2(x, topOffset)
        ..size = Vector2(w, blockAreaHeight);
      add(brick);
    }
  }
}
