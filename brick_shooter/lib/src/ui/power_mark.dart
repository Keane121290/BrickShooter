import 'dart:math' as math;
import 'dart:ui';

import '../game/player_profile.dart';

void paintPowerMark(Canvas canvas, Rect box, PowerUp kind, Color color) {
  switch (kind) {
    case PowerUp.extraTime:
      _clockPlus(canvas, box, color);
    case PowerUp.slowDown:
      _gaugeDown(canvas, box, color);
    case PowerUp.panic:
      _dynamite(canvas, box, color);
  }
}

void _clockPlus(Canvas canvas, Rect box, Color color) {
  final stroke = _stroke(color, box.shortestSide * 0.09);
  final center = Offset(box.left + box.width * 0.40, box.center.dy);
  final radius = box.shortestSide * 0.30;
  canvas.drawCircle(center, radius, stroke);
  canvas.drawCircle(center, stroke.strokeWidth * 0.7, Paint()..color = color);
  canvas.drawLine(center, center + Offset(0, -radius * 0.62), stroke);
  canvas.drawLine(center, center + Offset(radius * 0.48, radius * 0.22), stroke);

  final plus = Offset(box.right - box.width * 0.18, box.bottom - box.height * 0.30);
  final arm = box.shortestSide * 0.15;
  canvas.drawLine(plus + Offset(-arm, 0), plus + Offset(arm, 0), stroke);
  canvas.drawLine(plus + Offset(0, -arm), plus + Offset(0, arm), stroke);
}

void _gaugeDown(Canvas canvas, Rect box, Color color) {
  const arrow = Color(0xFF2F6BFF);
  final shaft = _stroke(arrow, box.shortestSide * 0.055);
  for (var i = 0; i < 3; i++) {
    final x = box.left + box.width * (0.22 + i * 0.28);
    final top = box.top + box.height * 0.04;
    final tipY = box.top + box.height * 0.34;
    canvas.drawLine(Offset(x, top), Offset(x, tipY - box.height * 0.07), shaft);
    canvas.drawPath(
      Path()
        ..moveTo(x, tipY)
        ..lineTo(x - box.width * 0.07, tipY - box.height * 0.09)
        ..lineTo(x + box.width * 0.07, tipY - box.height * 0.09)
        ..close(),
      Paint()..color = arrow,
    );
  }

  final center = Offset(box.center.dx, box.top + box.height * 0.68);
  final radius = box.shortestSide * 0.26;
  final dial = Rect.fromCircle(center: center, radius: radius);
  const segments = <Color>[
    Color(0xFF3DDC97),
    Color(0xFFFFE14A),
    Color(0xFFFF8A3D),
    Color(0xFF7A5CFF),
  ];
  final arc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = box.shortestSide * 0.09
    ..strokeCap = StrokeCap.butt;
  final sweep = -math.pi / segments.length;
  var start = math.pi;
  for (final segment in segments) {
    arc.color = segment;
    canvas.drawArc(dial, start, sweep, false, arc);
    start += sweep;
  }

  final needle = Color.lerp(const Color(0xFF2A241C), color, 0.2)!;
  final tip = center + Offset(-radius * 0.78, -radius * 0.18);
  canvas.drawLine(center, tip, _stroke(needle, box.shortestSide * 0.045));
  canvas.drawCircle(center, box.shortestSide * 0.065, Paint()..color = const Color(0xFFFF3B30));
  canvas.drawCircle(
    center,
    box.shortestSide * 0.065,
    _stroke(const Color(0xFFFFFFFF), box.shortestSide * 0.02),
  );
}

void _dynamite(Canvas canvas, Rect box, Color color) {
  const stickColor = Color(0xFFE23B3B);
  const capColor = Color(0xFFFF6A6A);
  const ropeColor = Color(0xFFF4E3C4);
  const ink = Color(0xFF3A2418);
  final edge = _stroke(ink, box.shortestSide * 0.035);

  void stick(Rect rect) {
    final body = RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.34));
    canvas.drawRRect(body, Paint()..color = stickColor);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(rect.center.dx, rect.top + rect.width * 0.18),
        width: rect.width * 0.9,
        height: rect.width * 0.36,
      ),
      Paint()..color = capColor,
    );
    canvas.drawRRect(body, edge);
  }

  final stickW = box.width * 0.26;
  final left = Rect.fromLTWH(
    box.left + box.width * 0.06,
    box.top + box.height * 0.30,
    stickW,
    box.height * 0.60,
  );
  final right = Rect.fromLTWH(
    box.right - box.width * 0.06 - stickW,
    box.top + box.height * 0.30,
    stickW,
    box.height * 0.60,
  );
  final mid = Rect.fromLTWH(
    box.center.dx - stickW * 0.55,
    box.top + box.height * 0.24,
    stickW * 1.1,
    box.height * 0.68,
  );
  stick(left);
  stick(right);
  stick(mid);

  final rope = RRect.fromRectAndRadius(
    Rect.fromLTWH(box.left + box.width * 0.04, box.top + box.height * 0.54, box.width * 0.92, box.height * 0.13),
    Radius.circular(box.height * 0.06),
  );
  canvas.drawRRect(rope, Paint()..color = ropeColor);
  canvas.drawRRect(rope, edge);

  final spark = Offset(mid.center.dx + box.width * 0.18, box.top + box.height * 0.08);
  final wick = Path()
    ..moveTo(mid.center.dx, mid.top)
    ..cubicTo(
      mid.center.dx + box.width * 0.02,
      box.top + box.height * 0.14,
      spark.dx + box.width * 0.04,
      box.top + box.height * 0.16,
      spark.dx,
      spark.dy,
    );
  canvas.drawPath(wick, _stroke(color, box.shortestSide * 0.045));
  canvas.drawCircle(spark, box.shortestSide * 0.055, Paint()..color = const Color(0xFFFFC83D));
  canvas.drawCircle(spark, box.shortestSide * 0.026, Paint()..color = const Color(0xFFFFF6C8));
}

Paint _stroke(Color color, double width) {
  return Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
}
