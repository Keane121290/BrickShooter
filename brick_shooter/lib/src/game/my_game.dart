// lib/src/game/my_game.dart
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background.dart';
import '../ui/overlays.dart';
import 'components/bullet.dart';      // BrickBullet (targetY + onArrive)
import 'components/row.dart';         // FallingRow (gapRow/customRow + fillLane + getSpeed)
import 'components/shooter.dart';
import 'components/board_grid.dart';

enum GameState { menu, playing, gameOver }

class MyGame extends FlameGame with TapDetector {
  // ---------- Designkonstanter ----------
  static const int lanes = 4;
  static const int rowsCapacityOnScreen = 12; // vi “designer” for 12 rader synlig
  static const int initialRows = 3;           // start med 3 rader
  static const double boardTop = 120;         // top-margin i logiske px

  // 2:3-forhold (bredde:høyde) for selve brikken
  static const double brickAspect = 2 / 3;

  // Radfart i rader/s (oppløsningsuavhengig)
  static const double rowSpeedStartRps = 0.85;
  static const double rowSpeedMaxRps   = 2.2;
  static const double rowAccelRpsPerS  = 0.05;

  // Skudd: raskt og skalerer med radfart
  static const double bulletBaseRps = 14.0; // minst 14 rader/s
  static const double bulletFactor  = 7.0;  // kule ≈ 7× radfart

  // ---------- Runtime/state ----------
  GameState state = GameState.menu;

  // Geometri (beregnes i onLoad)
  double floorY = 0;
  double laneWidth = 0;
  double padPx = 0;
  double brickWidth = 0;
  double brickHeight = 0;
  double rowHeight = 0;

  // Global fart i px/s (alle rader leser denne hver frame)
  double _rowSpeedPx = 0;
  double _bulletSpeedPx = 0;

  // Spawner: akkumuler **distanse** (px), ikke bare tid
  double _spawnDistAccumPx = 0;

  // Score
  int score = 0;
  int bestScore = 0;

  // Elementer
  final List<FallingRow> rows = [];
  final List<BrickBullet> bullets = [];

  // HUD
  final _scoreText = TextComponent(
    text: '0',
    position: Vector2(24, 24),
    anchor: Anchor.topLeft,
    priority: 1000,
  );

  // Visuelt
  late BackgroundScroller background;
  late BoardGrid boardGrid;
  late Shooter shooter;

  final _rng = Random();

  // ---------- Lifecycle ----------
  @override
  Future<void> onLoad() async {
    await _loadBestScore();

    final double w = size.x == 0 ? 1080.0 : size.x;
    final double h = size.y == 0 ? 1920.0 : size.y;

    // Responsiv dimensjonering
    laneWidth = w / lanes;

    // responsiv pad (lik margin rundt brikkene)
    padPx = (w * 0.018).clamp(10.0, 26.0);

    brickWidth  = (laneWidth - 2 * padPx).clamp(4.0, laneWidth);
    brickHeight = brickWidth / brickAspect;
    rowHeight   = brickHeight + 2 * padPx;

    // Skaler ned alt hvis 12 rader ikke får plass i høyden
    final neededHeight = boardTop + rowsCapacityOnScreen * rowHeight;
    if (neededHeight > h) {
      final scale = (h - boardTop) / (rowsCapacityOnScreen * rowHeight);
      padPx       *= scale;
      brickWidth  *= scale;
      brickHeight *= scale;
      rowHeight   *= scale;
    }

    // Gulv slik at akkurat 12 rader får plass
    floorY = boardTop + rowsCapacityOnScreen * rowHeight;

    // Startfarter i px/s
    _rowSpeedPx = rowSpeedStartRps * rowHeight;
    final startBulletRps = max(bulletBaseRps, rowSpeedStartRps * bulletFactor);
    _bulletSpeedPx = startBulletRps * rowHeight;

    // Komponenter
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

  // ---------- Input ----------
  @override
  void onTapDown(TapDownInfo info) {
    if (state != GameState.playing) return;
    final tapX = info.eventPosition.global.x;
    final lane = (tapX / laneWidth).floor().clamp(0, lanes - 1);
    _fireIntoColumn(lane);
  }

  // Kolonne-søk: finn ØVERSTE ledige plass (øverste hull eller tom celle)
  void _fireIntoColumn(int lane) {
    FallingRow? target;
    double? targetY;

    // Sorter rader etter "top" (minste top = øverst)
    final sorted = List<FallingRow>.from(rows)
      ..sort((a, b) {
        final ta = a.bottomY - a.brickHeight;
        final tb = b.bottomY - b.brickHeight;
        return ta.compareTo(tb);
      });

    for (final r in sorted) {
      if (!r.isMounted) continue;
      final hasHole = r.isGapRow ? (r.gapLane == lane)
          : !r.filledLanes!.contains(lane);
      if (!hasHole) continue;

      final rowTop = r.bottomY - r.brickHeight;
      if (r.bottomY >= boardTop && rowTop <= floorY) {
        target = r;
        targetY = r.bottomY; // kula “lander” i bunnen av den raden visuelt
        break;
      }
    }

    if (target == null) {
      // Ingen hull i kolonnen → lag/merge custom-rad på spawn Y
      final y = _topSpawnBottomY;
      _shootBulletTo(
        lane: lane,
        targetY: y,
        onArrive: () {
          _mergeOrSpawnPlayerRowWithBrick(lane);
          _repackBelt(); // hold griden tight
        },
      );
      return;
    }

    if (target.isGapRow) {
      // Treffe øverste gap → fjern raden, repack båndet (ingen hull i midten)
      _shootBulletTo(
        lane: lane,
        targetY: targetY!,
        onArrive: () {
          addScore(1);
          target!.removeFromParent();
          rows.remove(target);
          _repackBelt(); // <-- viktige endringen: tett igjen slotten umiddelbart
        },
      );
    } else {
      // Custom-rad: fyll lane om tom, og repack (snapp til grid)
      _shootBulletTo(
        lane: lane,
        targetY: targetY!,
        onArrive: () {
          if (!target!.filledLanes!.contains(lane)) {
            target!.fillLane(lane);
            _repackBelt();
          }
        },
      );
    }
  }

  void _shootBulletTo({
    required int lane,
    required double targetY,
    required void Function() onArrive,
  }) {
    final xCenter = lane * laneWidth + laneWidth / 2;
    final b = BrickBullet(
      lane: lane,
      xCenter: xCenter,
      bottomY: floorY - 8,
      speed: _bulletSpeedPx,                 // px/s (skalerer med radfart)
      size: Vector2(brickWidth, brickHeight),
      color: const ui.Color(0xFF53D769),
      targetY: targetY,
      onArrive: onArrive,
    )..priority = 50;

    bullets.add(b);
    add(b);
  }

  // ---------- Overlays ----------
  void startGame() {
    _reset();
    overlays.remove(MenuOverlay.id);
    overlays.remove(GameOverOverlay.id);

    _spawnDistAccumPx = 0;
    _rowSpeedPx = rowSpeedStartRps * rowHeight;

    // også init skudd-fart
    final startBulletRps = max(bulletBaseRps, rowSpeedStartRps * bulletFactor);
    _bulletSpeedPx = startBulletRps * rowHeight;

    background.setRunning(true);
    _setState(GameState.playing);

    // Start med 3 rader – perfekt på grid
    double bottom = boardTop + brickHeight + padPx;
    for (int i = 0; i < initialRows; i++) {
      _spawnGapRowAt(bottomY: bottom);
      bottom += rowHeight;
    }
    _repackBelt(); // sikrer nøyaktig grid-posisjon fra start
  }

  void backToMenu() {
    overlays.add(MenuOverlay.id);
    overlays.remove(GameOverOverlay.id);
    background.setRunning(false);
    _setState(GameState.menu);
  }

  void _setState(GameState s) {
    state = s;
    if (s == GameState.gameOver) {
      overlays.add(GameOverOverlay.id);
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
    _setState(GameState.gameOver);
  }

  // ---------- Rader / spawner ----------
  void _spawnGapRow() => _spawnGapRowAt(bottomY: _topSpawnBottomY);

  void _spawnGapRowAt({required double bottomY}) {
    final gapLane = _rng.nextInt(lanes);
    final r = FallingRow.gapRow(
      lanes: lanes,
      laneWidth: laneWidth,
      rowHeight: rowHeight,
      pad: padPx,
      bottomY: bottomY,
      getSpeed: () => _rowSpeedPx, // felles global fart for alle rader
      color: const ui.Color(0xFF2FB3FF),
      gapLane: gapLane,
    )..priority = 20;

    rows.add(r);
    add(r);
  }

  double get _topSpawnBottomY => boardTop + brickHeight + padPx;
  static const double _spawnSnapEpsilon = 0.5;

  FallingRow? _getTopCustomRowAtSpawn() {
    for (final r in rows) {
      if (!r.isMounted || r.isGapRow) continue;
      if ((r.bottomY - _topSpawnBottomY).abs() <= _spawnSnapEpsilon) {
        return r;
      }
    }
    return null;
  }

  void _mergeOrSpawnPlayerRowWithBrick(int lane) {
    final existing = _getTopCustomRowAtSpawn();
    if (existing != null) {
      existing.fillLane(lane);
      return;
    }
    final r = FallingRow.customRow(
      lanes: lanes,
      laneWidth: laneWidth,
      rowHeight: rowHeight,
      pad: padPx,
      bottomY: _topSpawnBottomY,
      getSpeed: () => _rowSpeedPx,
      color: const ui.Color(0xFF2FB3FF),
      filledLanes: {lane},
    )..priority = 20;

    rows.add(r);
    add(r);
  }

  // ---------- Vanskelighetskurve ----------
  void _updateDifficulty(double dt) {
    // Øk radfart i rader/s og konverter til px/s (globalt)
    final currentRps = (_rowSpeedPx / rowHeight)
        .clamp(rowSpeedStartRps, rowSpeedMaxRps);
    final nextRps = (currentRps + rowAccelRpsPerS * dt)
        .clamp(rowSpeedStartRps, rowSpeedMaxRps);
    _rowSpeedPx = nextRps * rowHeight;

    // Skudd-hastighet følger radfart (men minst bulletBaseRps)
    final bulletRps = max(bulletBaseRps, nextRps * bulletFactor);
    _bulletSpeedPx = bulletRps * rowHeight;
  }

  // ---------- Update ----------
  @override
  void update(double dt) {
    super.update(dt);
    if (state != GameState.playing) return;

    _updateDifficulty(dt);

    // Spawn etter **distanse**: én rad per radhøyde
    _spawnDistAccumPx += _rowSpeedPx * dt;
    while (_spawnDistAccumPx >= rowHeight) {
      _spawnDistAccumPx -= rowHeight;
      _spawnGapRow();
    }

    // Game over: når en rad når bunnen
    for (final r in List<FallingRow>.from(rows)) {
      if (!r.isMounted) continue;
      if (r.bottomY >= floorY) {
        gameOver();
        return;
      }
    }
  }

  // ---------- Repack: hold samlebåndet tett (ingen tomme slots) ----------
  void _repackBelt() {
    if (rows.isEmpty) return;

    // 1) Sortér etter "top" (øverst først)
    rows.sort((a, b) {
      final ta = a.bottomY - a.brickHeight;
      final tb = b.bottomY - b.brickHeight;
      return ta.compareTo(tb);
    });

    // 2) Sett hver rad på eksakt grid-posisjon: topStart + i*rowHeight
    double nextTop = boardTop; // første rad sitt "top"
    for (final r in rows) {
      if (!r.isMounted) continue;
      final desiredBottom = nextTop + r.brickHeight;
      // flytt direkte (snap) – gir “rykk opp”/“tett igjen” visuelt
      r.y = desiredBottom;
      r.bottomY = desiredBottom;
      nextTop += rowHeight;
    }
  }

  // ---------- Reset ----------
  void _reset() {
    for (final r in rows) { r.removeFromParent(); }
    rows.clear();
    for (final b in bullets) { b.removeFromParent(); }
    bullets.clear();
    score = 0;
    _scoreText.text = '0';
  }
}
