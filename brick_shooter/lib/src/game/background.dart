import 'dart:ui' as ui;
import 'package:flame/components.dart';

class BackgroundScroller extends Component with HasGameRef {
  final double width;
  final double height;
  final double floorY;

  bool _running = false;

  final ui.Color bg = const ui.Color(0xFF0F1115);
  final ui.Color stripe1 = const ui.Color(0xFF141821);
  final ui.Color stripe2 = const ui.Color(0xFF1A2030);
  final ui.Color floorColor = const ui.Color(0xFF2A2F3A);

  late final RectangleComponent _bgRect;
  late final RectangleComponent _floorLine;

  late final _StripeLayer layerSlow;
  late final _StripeLayer layerMid;
  late final _StripeLayer layerFast;

  BackgroundScroller({
    required this.width,
    required this.height,
    required this.floorY,
  });

  @override
  Future<void> onLoad() async {
    priority = -1000;

    _bgRect = RectangleComponent(
      position: Vector2.zero(),
      size: Vector2(width, height),
      paint: ui.Paint()..color = bg,
    )..priority = -1000;
    add(_bgRect);

    _floorLine = RectangleComponent(
      position: Vector2(0, floorY),
      size: Vector2(width, 8),
      paint: ui.Paint()..color = floorColor,
    )..priority = -500;
    add(_floorLine);

    layerSlow = _StripeLayer(width: width, height: 220, y: floorY - 380, color: stripe1, speed: 40, priority: -900);
    layerMid  = _StripeLayer(width: width, height: 160, y: floorY - 240, color: stripe2, speed: 90, priority: -850);
    layerFast = _StripeLayer(width: width, height: 100, y: floorY - 120, color: stripe1, speed: 160, priority: -800);

    add(layerSlow);
    add(layerMid);
    add(layerFast);
  }

  void setRunning(bool run) => _running = run;

  @override
  void update(double dt) {
    super.update(dt);
    if (!_running) return;
    layerSlow.advance(dt);
    layerMid.advance(dt);
    layerFast.advance(dt);
  }
}

class _StripeLayer extends Component {
  final double width;
  final double height;
  final double y;
  final ui.Color color;
  final double speed;

  late final RectangleComponent a;
  late final RectangleComponent b;

  _StripeLayer({
    required this.width,
    required this.height,
    required this.y,
    required this.color,
    required this.speed,
    required int priority,
  }) {
    this.priority = priority;
  }

  @override
  Future<void> onLoad() async {
    a = RectangleComponent(
      size: Vector2(width, height),
      position: Vector2(0, y),
      paint: ui.Paint()..color = color,
    )..priority = priority;

    b = RectangleComponent(
      size: Vector2(width, height),
      position: Vector2(width, y),
      paint: ui.Paint()..color = color,
    )..priority = priority;

    add(a);
    add(b);
  }

  void advance(double dt) {
    a.x -= speed * dt;
    b.x -= speed * dt;

    if (a.x + width < 0) a.x = b.x + width;
    if (b.x + width < 0) b.x = a.x + width;
  }
}
