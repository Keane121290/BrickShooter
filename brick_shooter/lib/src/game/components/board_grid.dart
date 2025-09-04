import 'dart:ui' as ui;
import 'package:flame/components.dart';

/// Tegner vertikale linjer (kolonnedividere) over spillefeltet for tydelig 4-deling.
class BoardGrid extends Component {
  final int lanes;
  final double laneWidth;
  final double top;
  final double bottom;
  final ui.Color lineColor;
  final double lineWidth;

  BoardGrid({
    required this.lanes,
    required this.laneWidth,
    required this.top,
    required this.bottom,
    required this.lineColor,
    required this.lineWidth,
  });

  @override
  Future<void> onLoad() async {
    // Tegn lane-linjer 1..lanes-1
    for (int i = 1; i < lanes; i++) {
      final x = i * laneWidth;
      add(
        RectangleComponent(
          position: Vector2(x - lineWidth / 2, top),
          size: Vector2(lineWidth, bottom - top),
          paint: ui.Paint()..color = lineColor,
        ),
      );
    }
  }
}
