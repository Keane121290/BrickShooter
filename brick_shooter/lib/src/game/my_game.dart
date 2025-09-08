import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'state.dart';
import 'visuals/effects.dart';
import 'systems/difficulty_controller.dart';
import 'systems/row_controller.dart';
import 'systems/bullet_controller.dart';

import 'background.dart';
import '../ui/overlays.dart';
import 'components/row.dart';
import 'components/shooter.dart';
import 'components/board_grid.dart';

class MyGame extends FlameGame with TapCallbacks {
  // Geometri
  double floorY = 0;
  double laneWidth = 0;
  double padPx = 0;
  double brickWidth = 0;
  double brickHeight = 0;
  double rowHeight = 0;

  // Tilstand
  GameState state = GameState.menu;
  final score = ScoreState();

  // HUD
  final _scoreText = TextComponent(
    text: '0',
    position: Vector2(24, 24),
    anchor: Anchor.topLeft,
    priority: 1000,
  );

  // Systemer
  late DifficultyController difficulty;
  late RowController rowController;
  late BulletController bulletController;

  // Visuelt
  late BackgroundScroller background;
  late BoardGrid boardGrid;
  late Shooter shooter;

  final _rng = Random();

  @override
  Future<void> onLoad() async {
    await _loadBest();

    final double w = size.x == 0 ? 1080.0 : size.x;
    final double h = size.y == 0 ? 1920.0 : size.y;

    laneWidth = w / GameConfig.lanes;
    padPx = (w * 0.018).clamp(10.0, 26.0);
    brickWidth  = (laneWidth - 2 * padPx).clamp(4.0, laneWidth);
    brickHeight = brickWidth / GameConfig.brickAspect;
    rowHeight   = brickHeight + 2 * padPx;

    final needed = GameConfig.boardTop + GameConfig.rowsCapacityOnScreen * rowHeight;
    if (needed > h) {
      final s = (h - GameConfig.boardTop) /
          (GameConfig.rowsCapacityOnScreen * rowHeight);
      padPx       *= s;
      brickWidth  *= s;
      brickHeight *= s;
      rowHeight   *= s;
    }
    floorY = GameConfig.boardTop + GameConfig.rowsCapacityOnScreen * rowHeight;

    // Systemer
    difficulty = DifficultyController(rowHeight: rowHeight);
    add(difficulty);

    rowController = RowController(
      boardTop: GameConfig.boardTop,
      floorY: floorY,
      lanes: GameConfig.lanes,
      laneWidth: laneWidth,
      rowHeight: rowHeight,
      padPx: padPx,
      rowSpeedPx: () => difficulty.rowPxPerSec,
      rowColor: const ui.Color(0xFF2FB3FF),
    );
    add(rowController);

    bulletController = BulletController(
      floorY: floorY,
      laneWidth: laneWidth,
      bulletPxPerSec: () => difficulty.bulletPxPerSec,
    );
    add(bulletController);

    // Scene
    background = BackgroundScroller(width: w, height: h, floorY: floorY);
    add(background);

    boardGrid = BoardGrid(
      lanes: GameConfig.lanes,
      laneWidth: laneWidth,
      top: GameConfig.boardTop,
      bottom: floorY,
      lineColor: const ui.Color(0xFF222937),
      lineWidth: 2,
    )..priority = -700;
    add(boardGrid);

    shooter = Shooter(
      lanes: GameConfig.lanes,
      laneWidth: laneWidth,
      y: floorY,
      width: w,
      height: 110,
    )..priority = 10;
    add(shooter);

    add(_scoreText);

    _setState(GameState.menu);
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    score.best = prefs.getInt('bestScore') ?? 0;
  }

  Future<void> _saveBest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bestScore', score.best);
  }

  // Input
  @override
  void onTapDown(TapDownEvent event) {
    if (state != GameState.playing) return;
    final lane = (event.canvasPosition.x / laneWidth)
        .floor()
        .clamp(0, GameConfig.lanes - 1);
    _fireIntoColumn(lane);
  }

  // Skyting (bruker controllere)
  void _fireIntoColumn(int lane) {
    final target = rowController.firstLegalTarget(lane);
    final ghostGreen = const ui.Color(0xFF53D769);

    if (target == null) {
      // ingen lovlig => reserver/lag spillerad på topp
      final topRow = rowController.reserveOnTop(lane, ghostColor: ghostGreen);
      bulletController.cancelHigherInLane(lane, rowController.spawnBottomY);

      bulletController.shoot(
        lane: lane,
        targetYResolver: () => rowController.spawnBottomY,
        brickSize: Vector2(brickWidth, brickHeight),
        color: const ui.Color(0xFF53D769),
        onArrive: () {
          rowController.fill(topRow, lane);
        },
        onCancel: () {
          rowController.unreserve(topRow, lane);
        },
      );
      return;
    }

    // reserver hullet i target og kanseller høyere kuler
    final ok = rowController.reserve(target, lane, ghostColor: ghostGreen);
    if (!ok) return;
    bulletController.cancelHigherInLane(lane, target.bottomY);

    bulletController.shoot(
      lane: lane,
      targetYResolver: () => target.bottomY,
      brickSize: Vector2(brickWidth, brickHeight),
      color: const ui.Color(0xFF53D769),
      onArrive: () {
        final becameFull = rowController.fill(target, lane);
        if (becameFull) {
          target.pendingClear = true;
          bulletController.cancelHigherInLane(lane, target.bottomY);
          if (rowController.isBottomRow(target)) {
            _explodeRow(target);
            _removeRowImmediate(target);
            _addScore(1);
          }
        }
      },
      onCancel: () {
        rowController.unreserve(target, lane);
      },
    );
  }

  // Explode + fjerne (spegler tidligere effekt)
  void _explodeRow(FallingRow row) {
    for (int lane = 0; lane < GameConfig.lanes; lane++) {
      if (!row.filledLanes.contains(lane)) continue;
      final cx = lane * laneWidth + padPx + (brickWidth / 2);
      final cy = row.bottomY - (brickHeight / 2);
      emitSquareBurst(this, Vector2(cx, cy), row.color);
    }
  }

  void _removeRowImmediate(FallingRow row) {
    row.removeFromParent();
    rowController.rows.remove(row);
  }

  // Overlays & state
  void _setState(GameState s) {
    state = s;
    if (s == GameState.menu) {
      overlays.add(MenuOverlay.id);
      overlays.remove(GameOverOverlay.id);
    } else if (s == GameState.playing) {
      overlays.remove(MenuOverlay.id);
      overlays.remove(GameOverOverlay.id);
    } else {
      overlays.add(GameOverOverlay.id);
      overlays.remove(MenuOverlay.id);
    }
  }

  void startGame() {
    _reset();

    overlays.remove(MenuOverlay.id);
    overlays.remove(GameOverOverlay.id);

    background.setRunning(true);
    _setState(GameState.playing);

    rowController.spawnInitial(
      visible: GameConfig.initialRows,
      prebuffer: GameConfig.prebufferRows,
    );
  }

  void backToMenu() {
    overlays.add(MenuOverlay.id);
    overlays.remove(GameOverOverlay.id);
    background.setRunning(false);
    _setState(GameState.menu);
  }

  void _addScore(int v) {
    score.add(v);
    if (score.score > score.best) {
      score.best = score.score;
      _saveBest();
    }
    _scoreText.text = '${score.score}';
  }

  void gameOver() {
    if (state != GameState.playing) return;

    background.setRunning(false);
    // Stopp videre spawn (ved å fjerne difficulty/controllere fra update)
    // enklest: sett overlay og ikke skyte mer. Rader vil fortsatt flyttes
    // av Difficulty; derfor fryser vi spillet ved å fjerne controller-update:
    difficulty.removeFromParent();
    // og frys kuler (pause via bullet-controller: sett speed null via ny instans)
    // her gjør vi enkelt: bytt state og ikke prosesser input/spawn/clear
    _setState(GameState.gameOver);
  }

  // Update loop
  @override
  void update(double dt) {
    super.update(dt);
    if (state != GameState.playing) return;

    // 1) CLEAR nederst først
    rowController.clearBottomIfPending(onExplode: _explodeRow);

    // 2) SPAWN via distanse-akkumulator
    rowController.tickSpawn(dt);

    // 3) FLOOR: hvis en bunnrad (ikke pendingClear) når gulvet → game over
    for (final r in List<FallingRow>.from(rowController.rows)) {
      if (!r.isMounted) continue;
      if (r.pendingClear) continue;
      if (r.bottomY >= floorY) {
        gameOver();
        return;
      }
    }
  }

  void _reset() {
    // tøm rader/kuler
    for (final r in rowController.rows) {
      r.removeFromParent();
    }
    rowController.rows.clear();

    // difficulty på nytt (i tilfelle game over fjernet den)
    if (!children.contains(difficulty)) add(difficulty);
    score.reset();
    _scoreText.text = '0';
  }
}
