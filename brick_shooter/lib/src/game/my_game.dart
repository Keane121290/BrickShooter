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

enum GamePhase {
  menu,
  tutorialDrop, // rader faller til rød linje
  tutorialHold, // rader pauset; vis hint; vent på korrekt tap
  playing,
  gameOver,
}

/// En enkel komponent som tegner en horisontal linje.
class SolidLine extends PositionComponent {
  final ui.Color color;
  final double thickness;
  SolidLine({
    required Vector2 from,
    required Vector2 to,
    required this.color,
    this.thickness = 3,
    int priority = -100,
  }) {
    position = from;
    size = Vector2(to.x - from.x, thickness);
    this.priority = priority;
    anchor = Anchor.topLeft;
  }

  @override
  void render(ui.Canvas canvas) {
    final paint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill;
    canvas.drawRect(size.toRect(), paint);
  }
}

/// Stiplet vertikal linje i valgt kolonne (for hint)
class DashedLine extends PositionComponent {
  final ui.Color color;
  final double dash;
  final double gap;
  DashedLine({
    required double x,
    required double yTop,
    required double yBottom,
    required this.color,
    this.dash = 10,
    this.gap = 6,
    int priority = 999,
  }) {
    position = Vector2(x, yTop);
    size = Vector2(2, yBottom - yTop);
    this.priority = priority;
    anchor = Anchor.topLeft;
  }

  @override
  void render(ui.Canvas canvas) {
    final paint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill;
    double y = 0;
    while (y < size.y) {
      final h = (y + dash <= size.y) ? dash : (size.y - y);
      canvas.drawRect(ui.Rect.fromLTWH(0, y, size.x, h), paint);
      y += dash + gap;
    }
  }
}

/// Emoji-hint for 👆 (peker) plassert over lane-senteret
class FingerHint extends TextComponent {
  FingerHint({required Vector2 center, int priority = 999})
      : super(
    text: '👆',
    anchor: Anchor.center,
    position: center,
    priority: priority,
  );
}

class MyGame extends FlameGame with TapCallbacks {
  double floorY = 0;
  double laneWidth = 0;
  double padPx = 0;
  double brickWidth = 0;
  double brickHeight = 0;
  double rowHeight = 0;

  GamePhase phase = GamePhase.menu;
  final score = ScoreState();

  final _scoreText = TextComponent(
    text: '0',
    position: Vector2(24, 24),
    anchor: Anchor.topLeft,
    priority: 1000,
  );

  final _debugText = TextComponent(
    text: '',
    position: Vector2(24, 52),
    anchor: Anchor.topLeft,
    priority: 1000,
  );

  late DifficultyController difficulty;
  late RowController rowController;
  late BulletController bulletController;

  late BackgroundScroller background;
  late BoardGrid boardGrid;
  late Shooter shooter;

  // lane locks + queue (en kule i lufta per lane)
  late List<bool> _laneLocked;
  late List<int> _laneQueue;

  // Tutorial UI
  late double tutorialLineY;
  SolidLine? _redLine;
  DashedLine? _dashLine;
  FingerHint? _finger;
  int? _tutorialLane; // lane som har hullet i nederste synlige rad ved hold

  final _rng = Random();

  @override
  Future<void> onLoad() async {
    await _loadBest();

    final double w = size.x == 0 ? 1080.0 : size.x;
    final double h = size.y == 0 ? 1920.0 : size.y;

    laneWidth = w / GameConfig.lanes;
    padPx = (w * 0.018).clamp(10.0, 26.0);
    brickWidth = (laneWidth - 2 * padPx).clamp(4.0, laneWidth);
    brickHeight = brickWidth / GameConfig.brickAspect;
    rowHeight = brickHeight + 2 * padPx;

    final needed =
        GameConfig.boardTop + GameConfig.rowsCapacityOnScreen * rowHeight;
    if (needed > h) {
      final s = (h - GameConfig.boardTop) /
          (GameConfig.rowsCapacityOnScreen * rowHeight);
      padPx *= s;
      brickWidth *= s;
      brickHeight *= s;
      rowHeight *= s;
    }
    floorY = GameConfig.boardTop + GameConfig.rowsCapacityOnScreen * rowHeight;

    // Tutorial-linje (ca. 3 rader ned fra toppen for å matche originalen)
    tutorialLineY = GameConfig.boardTop + rowHeight * 3;

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
      // Fart aktiv i tutorialDrop & playing, 0 ellers
      rowSpeedPx: () =>
      (phase == GamePhase.playing || phase == GamePhase.tutorialDrop)
          ? difficulty.rowPxPerSec
          : 0.0,
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
    background = BackgroundScroller(width: w, height: h, floorY: floorY)
      ..priority = -1000;
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
    add(_debugText);

    _laneLocked = List<bool>.filled(GameConfig.lanes, false);
    _laneQueue = List<int>.filled(GameConfig.lanes, 0);

    _setPhase(GamePhase.menu);
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    score.best = prefs.getInt('bestScore') ?? 0;
  }

  Future<void> _saveBest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bestScore', score.best);
  }

  @override
  void onTapDown(TapDownEvent event) {
    final lane = (event.canvasPosition.x / laneWidth)
        .floor()
        .clamp(0, GameConfig.lanes - 1);

    if (phase == GamePhase.playing) {
      _enqueueFire(lane);
      return;
    }

    if (phase == GamePhase.tutorialHold) {
      // Tap-to-play: kun korrekt lane starter
      if (_tutorialLane != null && lane == _tutorialLane) {
        // Skyt EN kule rett til riktig mål iht. “highest in run”
        _enqueueFire(lane);
        _clearTutorialUi();
        _setPhase(GamePhase.playing);
      }
      return;
    }
  }

  // --- lane lock / queue ---
  void _enqueueFire(int lane) {
    if (_laneLocked[lane]) {
      if (_laneQueue[lane] < 2) _laneQueue[lane] += 1;
      return;
    }
    _fireNow(lane);
  }

  void _fireNow(int lane) {
    _laneLocked[lane] = true;

    final ghostGreen = const ui.Color(0xFF53D769);

    // Bruk riktig targeting (øverste hullet i første frie run fra bunn)
    final target = rowController.landingTargetHighestInRun(lane);

    final ok = rowController.reserve(target, lane, ghostColor: ghostGreen);
    if (!ok) {
      _laneLocked[lane] = false;
      _drainQueueIfAny(lane);
      return;
    }

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
        _laneLocked[lane] = false;
        _drainQueueIfAny(lane);
      },
      onCancel: () {
        rowController.unreserve(target, lane);
        _laneLocked[lane] = false;
        _drainQueueIfAny(lane);
      },
    );
  }

  void _drainQueueIfAny(int lane) {
    if (_laneQueue[lane] > 0) {
      _laneQueue[lane] -= 1;
      _fireNow(lane);
    }
  }

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

  void _setPhase(GamePhase p) {
    phase = p;
    if (p == GamePhase.menu) {
      overlays.add(MenuOverlay.id);
      overlays.remove(GameOverOverlay.id);
    } else if (p == GamePhase.playing ||
        p == GamePhase.tutorialDrop ||
        p == GamePhase.tutorialHold) {
      overlays.remove(MenuOverlay.id);
      overlays.remove(GameOverOverlay.id);
    } else {
      overlays.add(GameOverOverlay.id);
      overlays.remove(MenuOverlay.id);
    }
  }

  void startGame() {
    // reset score + UI
    score.reset();
    _scoreText.text = '0';

    // nullstill låser/køer
    for (int i = 0; i < GameConfig.lanes; i++) {
      _laneLocked[i] = false;
      _laneQueue[i] = 0;
    }

    // spawn fresh
    if (!children.contains(difficulty)) add(difficulty);
    if (!children.contains(rowController)) add(rowController);
    if (!children.contains(bulletController)) add(bulletController);

    background.setRunning(true);

    rowController.spawnInitial(
      visible: GameConfig.initialRows,
      prebuffer: GameConfig.prebufferRows,
    );

    // legg på rød linje, gå inn i tutorialDrop
    _placeRedLine();
    _setPhase(GamePhase.tutorialDrop);
    bulletController.setPaused(false);
  }

  void backToMenu() {
    overlays.add(MenuOverlay.id);
    overlays.remove(GameOverOverlay.id);
    background.setRunning(false);
    _clearTutorialUi();
    _setPhase(GamePhase.menu);
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
    if (phase != GamePhase.playing) return;

    background.setRunning(false);
    bulletController.setPaused(true);
    _clearTutorialUi();
    _setPhase(GamePhase.gameOver);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Vedlikehold mot “dobbelt-rader”
    rowController.maintenanceDedupeAndSnap();

    if (phase == GamePhase.tutorialDrop) {
      // La radene falle til nederste rad treffer tutorialLineY
      final bottom = rowController.getBottomRow();
      if (bottom != null && bottom.bottomY >= tutorialLineY) {
        // pause rader
        _setPhase(GamePhase.tutorialHold);
        // Finn hullet i nederste rad ved hold og tegn hint
        _showTutorialHintForBottomGap();
      }
    }

    if (phase == GamePhase.playing) {
      // 1) CLEAR
      rowController.clearBottomIfPending(onExplode: _explodeRow);

      // 2) SPAWN
      rowController.tickSpawn(dt);

      // 3) FLOOR
      for (final r in List<FallingRow>.from(rowController.rows)) {
        if (!r.isMounted) continue;
        if (r.pendingClear) continue;
        if (r.bottomY >= floorY) {
          gameOver();
          return;
        }
      }
    }
  }

  // ---------- Tutorial UI helpers ----------

  void _placeRedLine() {
    _redLine?.removeFromParent();
    _redLine = SolidLine(
      from: Vector2(0, tutorialLineY),
      to: Vector2(size.x, tutorialLineY),
      color: const ui.Color(0xFFFF3B30), // rød
      thickness: 3,
      priority: 900,
    );
    add(_redLine!);
  }

  void _showTutorialHintForBottomGap() {
    // Finn nederste rad (synlig) og dens gap
    final bottom = rowController.getBottomRow();
    if (bottom == null) return;

    // gap = lane som IKKE er fylt eller reservert
    int? gapLane;
    for (int l = 0; l < GameConfig.lanes; l++) {
      final free =
          !bottom.filledLanes.contains(l) && !bottom.reservedLanes.contains(l);
      if (free) {
        gapLane = l;
        break;
      }
    }
    _tutorialLane = gapLane ?? 0;

    // Stiplet linje i denne kolonnen (fra toppen av brettet til rød linje)
    _dashLine?.removeFromParent();
    final xCenter = _tutorialLane! * laneWidth + laneWidth / 2;
    _dashLine = DashedLine(
      x: xCenter,
      yTop: GameConfig.boardTop,
      yBottom: tutorialLineY,
      color: const ui.Color(0x66FFFFFF),
      dash: 10,
      gap: 6,
      priority: 990,
    );
    add(_dashLine!);

    // Finger-hint like over rød linje
    _finger?.removeFromParent();
    _finger = FingerHint(
      center: Vector2(xCenter, tutorialLineY - 28),
      priority: 991,
    );
    add(_finger!);
  }

  void _clearTutorialUi() {
    _redLine?.removeFromParent();
    _dashLine?.removeFromParent();
    _finger?.removeFromParent();
    _redLine = null;
    _dashLine = null;
    _finger = null;
    _tutorialLane = null;
  }
}
