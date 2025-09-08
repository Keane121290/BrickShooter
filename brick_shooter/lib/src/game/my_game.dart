import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background.dart';
import '../ui/overlays.dart';
import 'components/bullet.dart';
import 'components/row.dart';
import 'components/shooter.dart';
import 'components/board_grid.dart';

enum GameState { menu, playing, gameOver }

class MyGame extends FlameGame with TapCallbacks {
  // ---------- Design ----------
  static const int lanes = 4;
  static const int rowsCapacityOnScreen = 12;
  static const int initialRows = 3;
  static const int prebufferRows = 3;
  static const double boardTop = 120;
  static const double brickAspect = 2 / 3;

  static const double rowSpeedStartRps = 1.2;
  static const double rowSpeedMaxRps   = 2.6;
  static const double rowAccelRpsPerS  = 0.06;

  static const double bulletBaseRps = 50.0;
  static const double bulletFactor  = 7.0;

  GameState state = GameState.menu;

  double floorY = 0;
  double laneWidth = 0;
  double padPx = 0;
  double brickWidth = 0;
  double brickHeight = 0;
  double rowHeight = 0;

  double _rowSpeedPx = 0;
  double _bulletSpeedPx = 0;

  double _spawnDistAccumPx = 0;
  bool _spawningEnabled = false;

  int score = 0;
  int bestScore = 0;

  final List<FallingRow> rows = [];
  final List<BrickBullet> bullets = [];

  final _scoreText = TextComponent(
    text: '0',
    position: Vector2(24, 24),
    anchor: Anchor.topLeft,
    priority: 1000,
  );

  late BackgroundScroller background;
  late BoardGrid boardGrid;
  late Shooter shooter;

  final _rng = Random();

  @override
  Future<void> onLoad() async {
    await _loadBestScore();

    final double w = size.x == 0 ? 1080.0 : size.x;
    final double h = size.y == 0 ? 1920.0 : size.y;

    laneWidth = w / lanes;
    padPx = (w * 0.018).clamp(10.0, 26.0);
    brickWidth  = (laneWidth - 2 * padPx).clamp(4.0, laneWidth);
    brickHeight = brickWidth / brickAspect;
    rowHeight   = brickHeight + 2 * padPx;

    final neededHeight = boardTop + rowsCapacityOnScreen * rowHeight;
    if (neededHeight > h) {
      final scale = (h - boardTop) / (rowsCapacityOnScreen * rowHeight);
      padPx       *= scale;
      brickWidth  *= scale;
      brickHeight *= scale;
      rowHeight   *= scale;
    }

    floorY = boardTop + rowsCapacityOnScreen * rowHeight;

    _rowSpeedPx = rowSpeedStartRps * rowHeight;
    final startBulletRps = max(bulletBaseRps, rowSpeedStartRps * bulletFactor);
    _bulletSpeedPx = startBulletRps * rowHeight;

    background = BackgroundScroller(width: w, height: h, floorY: floorY);
    add(background);

    boardGrid = BoardGrid(
      lanes: lanes,
      laneWidth: laneWidth,
      top: boardTop,
      bottom: floorY,
      lineColor: const ui.Color(0xFF222937),
      lineWidth: 2,
    )..priority = -700;
    add(boardGrid);

    shooter = Shooter(
      lanes: lanes,
      laneWidth: laneWidth,
      y: floorY,
      width: w,
      height: 110,
    )..priority = 10;
    add(shooter);

    add(_scoreText);

    _setState(GameState.menu);
  }

  Future<void> _loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    bestScore = prefs.getInt('bestScore') ?? 0;
  }

  Future<void> _saveBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bestScore', bestScore);
  }

  double _gridTopForIndex(int idx) => boardTop + idx * rowHeight;
  double _gridBottomForIndex(int idx) => _gridTopForIndex(idx) + brickHeight;
  double get _spawnBottomY => _gridBottomForIndex(-1);

  @override
  void onTapDown(TapDownEvent event) {
    if (state != GameState.playing) return;
    final tapX = event.canvasPosition.x;
    final lane = (tapX / laneWidth).floor().clamp(0, lanes - 1);
    _fireIntoColumn(lane);
  }

  // ---- Kanseller høyere kuler i samme lane ved blokkering ----
  void _cancelHigherBulletsInLane(int lane, double blockingBottomY) {
    for (final b in List<BrickBullet>.from(bullets)) {
      if (!b.isMounted) continue;
      if (b.lane != lane) continue;

      final targetY = b.targetYResolver();
      if (targetY < blockingBottomY) {
        b.paused = true;
        b.removeFromParent();
      }
    }
  }

  void _fireIntoColumn(int lane) {
    final col = rows.where((r) {
      if (!r.isMounted) return false;
      final top = r.bottomY - r.brickHeight;
      return r.bottomY >= boardTop && top <= floorY;
    }).toList()
      ..sort((a, b) => a.bottomY.compareTo(b.bottomY));

    FallingRow? targetRow;

    for (final r in col) {
      final isFilled   = r.filledLanes.contains(lane);
      final isReserved = r.reservedLanes.contains(lane);

      if (isFilled || isReserved) break;
      if (r.hasFreeLane(lane)) {
        targetRow = r;
        break;
      }
    }

    if (targetRow == null) {
      _mergeOrReserveOnTop(lane);
      _shootBulletTo(
        lane: lane,
        targetYResolver: () => _spawnBottomY,
        onArrive: () {
          final topRow = _findRowNearBottom(_spawnBottomY);
          topRow?.fillLane(lane);
        },
        onCancel: () {
          final topRow = _findRowNearBottom(_spawnBottomY);
          topRow?.unreserveLane(lane);
        },
      );
      return;
    }

    final reserved = targetRow.reserveLane(lane, ghostColor: const ui.Color(0xFF53D769));
    if (!reserved) return;

    _cancelHigherBulletsInLane(lane, targetRow.bottomY);

    _shootBulletTo(
      lane: lane,
      targetYResolver: () => targetRow!.bottomY,
      onArrive: () {
        final becameFull = targetRow!.fillLane(lane);
        if (becameFull) {
          targetRow!.pendingClear = true;
          _cancelHigherBulletsInLane(lane, targetRow!.bottomY);

          if (_isBottomRow(targetRow!)) {
            _explodeRow(targetRow!);
            _removeRow(targetRow!);
            addScore(1);
          }
        }
      },
      onCancel: () {
        targetRow?.unreserveLane(lane);
      },
    );
  }

  FallingRow? _findRowNearBottom(double desiredBottom, {double eps = 1.6}) {
    for (final r in rows) {
      if (!r.isMounted) continue;
      if ((r.bottomY - desiredBottom).abs() <= eps) return r;
    }
    return null;
  }

  void _mergeOrReserveOnTop(int lane) {
    final existing = _findRowNearBottom(_spawnBottomY);
    if (existing != null) {
      existing.reserveLane(lane, ghostColor: const ui.Color(0xFF53D769));
      _cancelHigherBulletsInLane(lane, _spawnBottomY);
      return;
    }
    final r = FallingRow(
      lanes: lanes,
      laneWidth: laneWidth,
      rowHeight: rowHeight,
      pad: padPx,
      bottomY: _spawnBottomY,
      getSpeed: () => _rowSpeedPx,
      color: const ui.Color(0xFF2FB3FF),
      filledLanes: {},
    );
    r.reserveLane(lane, ghostColor: const ui.Color(0xFF53D769));
    rows.add(r);
    add(r);

    _cancelHigherBulletsInLane(lane, _spawnBottomY);
  }

  bool _isBottomRow(FallingRow row) {
    if (rows.isEmpty) return false;
    FallingRow? bottom = rows.first;
    for (final r in rows) {
      if (!r.isMounted) continue;
      if (r.bottomY > (bottom?.bottomY ?? -1e9)) bottom = r;
    }
    return identical(row, bottom);
  }

  void _removeRow(FallingRow r) {
    r.removeFromParent();
    rows.remove(r);
  }

  void _shootBulletTo({
    required int lane,
    required double Function() targetYResolver,
    required void Function() onArrive,
    void Function()? onCancel,
  }) {
    final xCenter = lane * laneWidth + laneWidth / 2;
    final b = BrickBullet(
      lane: lane,
      xCenter: xCenter,
      bottomY: floorY - 8,
      speed: _bulletSpeedPx,
      size: Vector2(brickWidth, brickHeight),
      color: const ui.Color(0xFF53D769),
      targetYResolver: targetYResolver,
      onArrive: onArrive,
      onCancel: onCancel,
    );

    bullets.add(b);
    add(b);
  }

  void startGame() {
    _reset();
    overlays.remove(MenuOverlay.id);
    overlays.remove(GameOverOverlay.id);

    _spawnDistAccumPx = 0;
    _spawningEnabled = true;

    _rowSpeedPx = rowSpeedStartRps * rowHeight;
    final startBulletRps = max(bulletBaseRps, rowSpeedStartRps * bulletFactor);
    _bulletSpeedPx = startBulletRps * rowHeight;

    background.setRunning(true);
    _setState(GameState.playing);

    for (int i = 0; i < initialRows; i++) {
      _spawnGapLikeRowAtGridIndex(i);
    }
    for (int i = prebufferRows; i >= 1; i--) {
      _spawnGapLikeRowAtGridIndex(-i);
    }
  }

  void backToMenu() {
    overlays.add(MenuOverlay.id);
    overlays.remove(GameOverOverlay.id);
    background.setRunning(false);
    _setState(GameState.menu);
  }

  void _setState(GameState s) {
    state = s;
    if (s == GameState.menu) {
      overlays.add(MenuOverlay.id);
      overlays.remove(GameOverOverlay.id);
    } else if (s == GameState.playing) {
      overlays.remove(MenuOverlay.id);
      overlays.remove(GameOverOverlay.id);
    } else if (s == GameState.gameOver) {
      overlays.add(GameOverOverlay.id);
      overlays.remove(MenuOverlay.id);
    }
  }

  void addScore(int v) {
    score += v;
    if (score > bestScore) {
      bestScore = score;
      _saveBestScore();
    }
    _scoreText.text = '$score';
  }

  void gameOver() {
    if (state != GameState.playing) return;
    background.setRunning(false);
    _rowSpeedPx = 0;
    _spawningEnabled = false;
    for (final b in bullets) {
      if (b.isMounted) b.paused = true;
    }
    _setState(GameState.gameOver);
  }

  void _spawnGapLikeRow() => _spawnGapLikeRowAtGridIndex(-1);

  void _spawnGapLikeRowAtGridIndex(int gridIndex) {
    final gapLane = _rng.nextInt(lanes);
    final all = List<int>.generate(lanes, (i) => i);
    final filled = all.where((i) => i != gapLane).toSet();

    final r = FallingRow(
      lanes: lanes,
      laneWidth: laneWidth,
      rowHeight: rowHeight,
      pad: padPx,
      bottomY: _gridBottomForIndex(gridIndex),
      getSpeed: () => _rowSpeedPx,
      color: const ui.Color(0xFF2FB3FF),
      filledLanes: filled,
    );

    rows.add(r);
    add(r);
  }

  void _updateDifficulty(double dt) {
    if (state != GameState.playing) return;
    final currentRps = (_rowSpeedPx / rowHeight)
        .clamp(rowSpeedStartRps, rowSpeedMaxRps);
    final nextRps = (currentRps + rowAccelRpsPerS * dt)
        .clamp(rowSpeedStartRps, rowSpeedMaxRps);
    _rowSpeedPx = nextRps * rowHeight;

    final bulletRps = max(bulletBaseRps, nextRps * bulletFactor);
    _bulletSpeedPx = bulletRps * rowHeight;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (state != GameState.playing) return;

    _updateDifficulty(dt);

    // CLEAR: fjern alle fulle nederste rader
    while (true) {
      final bottom = _getBottomRow();
      if (bottom == null) break;
      if (!bottom.pendingClear) break;
      _explodeRow(bottom);
      _removeRow(bottom);
      addScore(1);
    }

    // SPAWN
    if (_spawningEnabled) {
      _spawnDistAccumPx += _rowSpeedPx * dt;
      while (_spawnDistAccumPx >= rowHeight) {
        _spawnDistAccumPx -= rowHeight;
        _spawnGapLikeRow();
      }
    }

    // FLOOR
    for (final r in List<FallingRow>.from(rows)) {
      if (!r.isMounted) continue;
      if (r.pendingClear) continue;
      if (r.bottomY >= floorY) {
        gameOver();
        return;
      }
    }
  }

  FallingRow? _getBottomRow() {
    if (rows.isEmpty) return null;
    FallingRow? bottom;
    double maxY = -1e9;
    for (final r in rows) {
      if (!r.isMounted) continue;
      if (r.bottomY > maxY) {
        maxY = r.bottomY;
        bottom = r;
      }
    }
    return bottom;
  }

  void _explodeRow(FallingRow row) {
    for (int lane = 0; lane < lanes; lane++) {
      if (!row.filledLanes.contains(lane)) continue;
      final cx = lane * laneWidth + padPx + (brickWidth / 2);
      final cy = row.bottomY - (brickHeight / 2);
      _emitSquareBurst(Vector2(cx, cy), row.color);
    }
  }

  void _emitSquareBurst(Vector2 pos, ui.Color color) {
    final rnd = Random();
    add(
      ParticleSystemComponent(
        position: pos,
        priority: 60,
        particle: Particle.generate(
          count: 28,
          lifespan: 0.45,
          generator: (i) {
            final a = rnd.nextDouble() * 2 * pi;
            final r = 140 + rnd.nextDouble() * 120;
            final vx = cos(a) * r;
            final vy = sin(a) * r - 80;
            return AcceleratedParticle(
              acceleration: Vector2(0, 600),
              speed: Vector2(vx, vy),
              child: CircleParticle(
                radius: 2.2,
                paint: ui.Paint()..color = color.withOpacity(0.95),
              ),
            );
          },
        ),
      ),
    );
  }

  void _reset() {
    for (final r in rows) { r.removeFromParent(); }
    rows.clear();
    for (final b in bullets) { b.removeFromParent(); }
    bullets.clear();
    score = 0;
    _scoreText.text = '0';
  }
}
