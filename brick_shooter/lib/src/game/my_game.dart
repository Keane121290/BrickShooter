import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Game configuration and state
import 'config.dart';
import 'state.dart';

// Visual effects
import 'visuals/effects.dart';

// Game systems
import 'systems/difficulty_controller.dart';
import 'systems/row_controller.dart';
import 'systems/bullet_controller.dart';

// Background and UI
import 'background.dart';
import '../ui/overlays.dart';

// Game components
import 'components/row.dart';
import 'components/top_banner_filter.dart';
import 'components/shooter.dart';
import 'components/board_grid.dart';
import 'components/multiplier.dart';
import 'components/game_button.dart';
import 'components/timer_display.dart';

// Tutorial components
import 'components/tutorial/dashed_line.dart';
import 'components/tutorial/finger_hint.dart';

class MyGame extends FlameGame with TapCallbacks {
  // ========== Game State ==========
  GamePhase phase = GamePhase.menu;
  final score = ScoreState();

  // ========== Board Dimensions ==========
  double floorY = 0;
  double laneWidth = 0;
  double padPx = 0;
  double brickWidth = 0;
  double brickHeight = 0;
  double rowHeight = 0;
  double minimumBottomY = 0; // Minsteplassering for den nederste raden (stopY)

  // ========== Game Systems ==========
  late DifficultyController difficulty;
  late RowController rowController;
  late BulletController bulletController;

  // ========== Visual Components ==========
  late BackgroundScroller background;
  late BoardGrid boardGrid;
  late Shooter shooter;
  late Multiplier multiplier;
  late TopBannerFilter topBannerFilter;

  // ========== UI Components ==========
  final _scoreText = TextComponent(
    text: '0',
    position: Vector2(0, 24),
    anchor: Anchor.topLeft,
    priority: 1000,
  );

  TimerDisplay? _timerDisplay;
  double _timeRemaining = 90.0; // Start på 90 sekunder

  GameButton? _pauseButton;
  GameButton? _restartButton;

  // ========== Shooting System ==========
  // One-bullet-per-lane + tiny queue
  late List<bool> _laneLocked;
  late List<int> _laneQueue;

  // ========== Tutorial System ==========
  late double tutorialLineY;
  DashedLine? _dashLine;
  FingerHint? _finger;
  int? _tutorialLane; // lane with gap on the bottom row at hold time
  double _startAnimationTime = 0.0; // Time since game start/restart
  bool _isAnimating = false; // Whether start animations are in progress

  @override
  Future<void> onLoad() async {
    try {
      await _loadBest();
    } catch (e) {
      // Hvis loading feiler, fortsett med default verdi (0)
      debugPrint('Warning: Failed to load best score: $e');
    }

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
      final s =
          (h - GameConfig.boardTop) / (GameConfig.rowsCapacityOnScreen * rowHeight);
      padPx *= s;
      brickWidth *= s;
      brickHeight *= s;
      rowHeight *= s;
    }
    floorY = GameConfig.boardTop + GameConfig.rowsCapacityOnScreen * rowHeight;

    // Tutorial line at 1/3 of screen height
    tutorialLineY = h / 3;
    
    // Beregn minsteplassering (stopY) - samme som brukes i tutorialDrop
    minimumBottomY = tutorialLineY + rowHeight * 0.8;

    // Systems
    difficulty = DifficultyController(rowHeight: rowHeight);
    add(difficulty);

    rowController = RowController(
      boardTop: GameConfig.boardTop,
      floorY: floorY,
      lanes: GameConfig.lanes,
      laneWidth: laneWidth,
      rowHeight: rowHeight,
      padPx: padPx,
      // Speed is active in playing and tutorialDrop, 0 otherwise
      // During start animation (first 0.9 seconds), use 10x speed
      rowSpeedPx: () {
        // Allow speed in playing and tutorialDrop phases
        if (phase == GamePhase.playing || phase == GamePhase.tutorialDrop) {
          // During start animation (first 0.9 seconds), use 10x speed
          if (phase == GamePhase.tutorialDrop && _startAnimationTime < 0.9) {
            return difficulty.rowPxPerSec * 10.0;
          }
          return difficulty.rowPxPerSec;
        }
        // tutorialHold and other phases have speed 0
        return 0.0;
      },
      rowColor: const ui.Color(0xFF1A7AB8), // Mørkere blå for bedre kontrast med hvit tekst
    );
    // Sett minsteplassering for rader
    rowController.minimumBottomY = minimumBottomY;
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

    multiplier = Multiplier(
      width: w,
      floorY: floorY,
      getScore: () => score.score,
    )..priority = 100;
    add(multiplier);

    // Top banner filter - mørkt gradient over toppen for bedre kontrast med poengsummen
    const bannerHeight = 120.0; // Høyde på banner-filteret
    topBannerFilter = TopBannerFilter(
      width: w,
      height: bannerHeight,
    );
    add(topBannerFilter);

    // Set score text position to center horizontally and size to match brick height
    _scoreText.position = Vector2(w / 2, 24);
    _scoreText.anchor = Anchor.topCenter;
    _scoreText.textRenderer = TextPaint(
      style: TextStyle(
        fontSize: brickHeight,
        fontWeight: FontWeight.bold,
        color: ui.Color(0xFFFFFFFF),
      ),
    );
    add(_scoreText);

    // Legg til tidteller til høyre for poengsummen
    const timerMarginFromEdge = 20.0; // Margin fra høyre kant
    _timerDisplay = TimerDisplay(
      timeRemaining: _timeRemaining,
      fontSize: brickHeight * 0.7, // Litt mindre enn poengsummen
      textColor: const ui.Color(0xFFFFFFFF),
      x: 0, // Vil bli overskrevet
      y: 24,
    );
    // Sett anchor til topRight og posisjon til høyre kant
    _timerDisplay!.anchor = Anchor.topRight;
    _timerDisplay!.position = Vector2(w - timerMarginFromEdge, 24);
    add(_timerDisplay!);

    // Legg til pause og restart knapper til venstre for poengsummen
    // Knappene skal ha samme høyde som poengsummen (brickHeight) og være vertikalt sentrert
    final buttonSize = brickHeight;
    const buttonSpacing = 10.0;
    const marginFromEdge = 20.0; // Margin fra venstre kant
    
    // Poengsummen har anchor.topCenter på y=24, så senterlinjen er på y=24 + brickHeight/2
    // Knappene skal også ha senterlinjen på samme sted
    final buttonCenterY = 24.0 + brickHeight / 2;
    final buttonY = buttonCenterY - buttonSize / 2; // Topp av knappen
    
    // Plasser knappene fra venstre kant med margin
    final buttonStartX = marginFromEdge;

    _pauseButton = GameButton(
      buttonType: ButtonType.pause,
      backgroundColor: const ui.Color(0xFF1A7AB8), // Mørk blå
      iconColor: const ui.Color(0xFFFFFFFF),
      onTap: () {
        if (phase == GamePhase.playing) {
          _pauseGame();
        } else if (phase == GamePhase.paused) {
          _resumeGame();
        }
      },
      x: buttonStartX,
      y: buttonY,
      size: buttonSize,
    );
    add(_pauseButton!);

    _restartButton = GameButton(
      buttonType: ButtonType.restart,
      backgroundColor: const ui.Color(0xFF1A7AB8), // Mørk blå
      iconColor: const ui.Color(0xFFFFFFFF),
      onTap: () {
        if (phase == GamePhase.playing || phase == GamePhase.paused) {
          startGame();
        }
      },
      x: buttonStartX + buttonSize + buttonSpacing,
      y: buttonY,
      size: buttonSize,
    );
    add(_restartButton!);

    _laneLocked = List<bool>.filled(GameConfig.lanes, false);
    _laneQueue = List<int>.filled(GameConfig.lanes, 0);

    _setPhase(GamePhase.menu);
  }

  // ========== Input Handling ==========

  @override
  void onTapDown(TapDownEvent event) {
    // Disable input during first second of animations
    if (_isAnimating && _startAnimationTime < 1.0) {
      return;
    }

    // Sjekk om tap er på en knapp først (knappene håndterer sine egne taps)
    // Hvis ikke, håndter som vanlig lane-tap
    
    final lane = (event.canvasPosition.x / laneWidth)
        .floor()
        .clamp(0, GameConfig.lanes - 1);

    if (phase == GamePhase.playing) {
      _enqueueFire(lane);
      return;
    }

    if (phase == GamePhase.tutorialHold) {
      // Tap-to-play: only correct lane starts
      if (_tutorialLane != null && lane == _tutorialLane) {
        _enqueueFire(lane);
        _clearTutorialUi();
        _setPhase(GamePhase.playing);
      }
      return;
    }
  }

  // ========== Shooting Logic ==========

  void _enqueueFire(int lane) {
    if (_laneLocked[lane]) {
      if (_laneQueue[lane] < 2) _laneQueue[lane] += 1;
      return;
    }
    _fireNow(lane);
  }

  void _fireNow(int lane) {
    _laneLocked[lane] = true;

    // Choose target using the “highest in first free run from bottom” rule
    final target = rowController.landingTargetHighestInRun(lane);

    // Reserve; if fails (blocked or no space), unlock + drain queue
    final ok = rowController.reserve(target, lane);
    if (!ok) {
      _laneLocked[lane] = false;
      _drainQueueIfAny(lane);
      return;
    }

    // Cancel higher bullets in same lane that would overshoot
    bulletController.cancelHigherInLane(lane, target.bottomY);

    bulletController.shoot(
      lane: lane,
      targetYResolver: () => target.bottomY,
      brickSize: Vector2(brickWidth, brickHeight),
      color: const ui.Color(0xFF53D769),
      onArrive: () {
        // If target row disappeared meanwhile (race), just unlock & drain
        if (!target.isMounted) {
          _laneLocked[lane] = false;
          _drainQueueIfAny(lane);
          return;
        }

        final becameFull = rowController.fill(target, lane);
        if (becameFull) {
          target.pendingClear = true;
          bulletController.cancelHigherInLane(lane, target.bottomY);
          
          // For rapid shooting: immediately clear the row so next shot can target the next row
          // This allows rapid consecutive shots to work correctly
          final currentMultiplier = multiplier.getCurrentMultiplier();
          final clearedCount = rowController.clearBottomIfPending(onExplode: _explodeRow);
          if (clearedCount > 0) {
            _addScore(currentMultiplier * clearedCount);
          }
        }
        _laneLocked[lane] = false;
        _drainQueueIfAny(lane);
      },
      onCancel: () {
        if (target.isMounted) {
          rowController.unreserve(target, lane);
        }
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

  // ========== Game Flow Control ==========

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
    } else if (p == GamePhase.paused) {
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

    // Reset timer til 90 sekunder
    _timeRemaining = 90.0;
    if (_timerDisplay != null) {
      _timerDisplay!.timeRemaining = _timeRemaining;
    }

    // reset lane locks/queues
    for (int i = 0; i < GameConfig.lanes; i++) {
      _laneLocked[i] = false;
      _laneQueue[i] = 0;
    }

    // Reset difficulty/speed to start speed
    difficulty.resetToStartSpeed();
    difficulty.setPaused(false);

    if (!children.contains(difficulty)) add(difficulty);
    if (!children.contains(rowController)) add(rowController);
    if (!children.contains(bulletController)) add(bulletController);

    background.setRunning(true);

    // Reset animation timer før spawning
    _startAnimationTime = 0.0;
    _isAnimating = true;

    // Spawn rows above the top with animation
    // Radene skal animere ned til stopY (minimumBottomY)
    // Bruk spawnInitial med animasjonsparametere for å aktivere start-animasjonen
    rowController.spawnInitial(
      visible: GameConfig.initialRows,
      prebuffer: GameConfig.prebufferRows,
      startAnimationTargetY: minimumBottomY,
      startAnimationDuration: 0.45, // 0.45 sekunder for animasjonen (dobbelt hastighet)
    );

    // enter tutorialDrop phase
    _setPhase(GamePhase.tutorialDrop);
    bulletController.setPaused(false);
    
    // Set pause button icon to pause (not play)
    if (_pauseButton != null) {
      _pauseButton!.buttonType = ButtonType.pause;
    }
  }

  void backToMenu() {
    overlays.add(MenuOverlay.id);
    overlays.remove(GameOverOverlay.id);
    background.setRunning(false);
    _clearTutorialUi();
    _setPhase(GamePhase.menu);
  }

  void _pauseGame() {
    if (phase != GamePhase.playing) return;
    bulletController.setPaused(true);
    difficulty.setPaused(true);
    background.setRunning(false);
    _setPhase(GamePhase.paused);
    if (_pauseButton != null) {
      _pauseButton!.buttonType = ButtonType.play; // Endre ikon til play
    }
  }

  void _resumeGame() {
    if (phase != GamePhase.paused) return;
    bulletController.setPaused(false);
    difficulty.setPaused(false);
    background.setRunning(true);
    _setPhase(GamePhase.playing);
    if (_pauseButton != null) {
      _pauseButton!.buttonType = ButtonType.pause; // Endre ikon tilbake til pause
    }
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

    // Oppdater start animation time kontinuerlig når vi er i tutorialDrop eller playing fase
    if (phase == GamePhase.tutorialDrop || phase == GamePhase.playing || phase == GamePhase.tutorialHold) {
      _startAnimationTime += dt;
    }

    // Oppdater timer kun når spillet kjører (playing fase) og ikke er pauset
    if (phase == GamePhase.playing && _timerDisplay != null) {
      _timeRemaining -= dt;
      if (_timeRemaining < 0) {
        _timeRemaining = 0;
        // Timer har gått ut - kan legge til game over logikk her hvis ønskelig
      }
      _timerDisplay!.timeRemaining = _timeRemaining;
    }
    
    // Handle start animations
    if (_isAnimating) {
      // Dashed line and finger hint appear after 1 second and fade in quickly
      if (_startAnimationTime >= 1.0) {
        if (_dashLine != null || _finger != null) {
          // Quick fade-in: from 0 to 1 over 0.2 seconds (starting at 1.0)
          final fadeStartTime = 1.0;
          final fadeDuration = 0.2;
          final fadeProgress = ((_startAnimationTime - fadeStartTime) / fadeDuration).clamp(0.0, 1.0);
          
          if (_dashLine != null) {
            _dashLine!.setOpacity(fadeProgress);
          }
          if (_finger != null) {
            _finger!.setOpacity(fadeProgress);
          }
        }
        
        // Stop animating after fade-ins complete
        if (_startAnimationTime >= 1.0 + 0.2) {
          _isAnimating = false;
        }
      }
    }

    // Keep rows ordered bottom->top to stabilize logic
    // I tutorialDrop og playing fase, ikke snapp til grid - la radene bevege seg fritt
    // I tutorialHold fase, snapp til grid for å unngå overlapp
    // Overlapp-fiksing skjer alltid, men grid-snapping kun når radene skal stoppe
    final shouldSnap = phase == GamePhase.tutorialHold;
    rowController.maintenanceDedupeAndSnap(allowSnap: shouldSnap);

    if (phase == GamePhase.tutorialDrop) {
      final bottom = rowController.getBottomRow();
      
      // Vent til start-animasjonen er ferdig før vi sjekker stopp-posisjon
      if (!rowController.isStartAnimation) {
        // Check if bottom row has reached the stop position
        // Stop at minimumBottomY (0.8 row heights below tutorialLineY)
        if (bottom != null && bottom.bottomY >= minimumBottomY) {
          // Stop rows from moving further
          _setPhase(GamePhase.tutorialHold);
        }
      } else {
        // Under start-animasjonen, sjekk om animasjonen er ferdig
        // Stopp animasjonen NÅR den nederste raden når minimumBottomY
        // Ikke stopp basert på tid alene - radene må faktisk nå målet
        if (bottom != null && bottom.bottomY >= minimumBottomY) {
          rowController.endStartAnimation();
        }
      }
    }

    // Show tutorial hint when animation time reaches 1 second (if we're in tutorialHold and hint not shown yet)
    if (phase == GamePhase.tutorialHold && _startAnimationTime >= 1.0 && _dashLine == null && _finger == null) {
      _showTutorialHintForBottomGap();
    }

    if (phase == GamePhase.playing) {
      // 1) CLEAR bottom if pending (may chain)
      // Get multiplier before clearing (so all rows in batch use same multiplier)
      final currentMultiplier = multiplier.getCurrentMultiplier();
      final clearedCount = rowController.clearBottomIfPending(onExplode: _explodeRow);
      
      // Add score for all cleared rows (multiplier × number of rows)
      if (clearedCount > 0) {
        _addScore(currentMultiplier * clearedCount);
      }

      // 2) RECYCLE rader som går ut av skjermen (pre-genererte 500 rader)
      rowController.tickSpawn(dt);
      
      // 3) Sjekk kontinuerlig at den nederste raden respekterer minsteplassering
      // Dette må gjøres etter både fjerning og spawning
      rowController.ensureMinimumPosition();
      
      // 4) Sjekk kontinuerlig at det er nok rader over toppen
      rowController.ensureRowsAboveTop();

      // 3) FLOOR check
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

  // ========== Score Management ==========

  void _addScore(int v) {
    score.add(v);
    if (score.score > score.best) {
      score.best = score.score;
      score.newBest = true;
      _saveBest();
    }
    _scoreText.text = '${score.score}';
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    score.best = prefs.getInt('bestScore') ?? 0;
  }

  Future<void> _saveBest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bestScore', score.best);
  }

  // ========== Visual Effects ==========

  void _explodeRow(FallingRow row) {
    for (int lane = 0; lane < GameConfig.lanes; lane++) {
      if (!row.filledLanes.contains(lane)) continue;
      final cx = lane * laneWidth + padPx + (brickWidth / 2);
      final cy = row.bottomY - (brickHeight / 2);
      emitSquareBurst(this, Vector2(cx, cy), row.color);
    }
  }

  // ========== Tutorial System ==========

  void _showTutorialHintForBottomGap() {
    final bottom = rowController.getBottomRow();
    if (bottom == null) return;

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

    _dashLine?.removeFromParent();
    final xCenter = _tutorialLane! * laneWidth + laneWidth / 2;
    
    // Position hint between tutorial stop position and multiplier line
    // Multiplier line is at floorY, multiplier text/bar is at floorY - 50
    // Tutorial stop position is at minimumBottomY
    // Add spacing from both lines
    const spacingFromTutorialStop = 30.0;
    const spacingFromMultiplier = 30.0;
    final dashLineTop = minimumBottomY + spacingFromTutorialStop;
    final dashLineBottom = floorY - 50 - spacingFromMultiplier;
    
    // Position hand in the middle of the dashed line area
    final hintY = dashLineTop + (dashLineBottom - dashLineTop) * 0.5;
    
    _dashLine = DashedLine(
      x: xCenter,
      yTop: dashLineTop,
      yBottom: dashLineBottom,
      color: const ui.Color(0xCCFFFFFF), // Much clearer/more opaque
      dash: 10,
      gap: 6,
      lineWidth: 3.0, // Thicker line
      priority: 990,
    );
    // Set initial opacity based on animation time
    if (_startAnimationTime >= 1.0) {
      final fadeStartTime = 1.0;
      final fadeDuration = 0.2;
      final fadeProgress = ((_startAnimationTime - fadeStartTime) / fadeDuration).clamp(0.0, 1.0);
      _dashLine!.setOpacity(fadeProgress);
    }
    add(_dashLine!);

    _finger?.removeFromParent();
    _finger = FingerHint(
      center: Vector2(xCenter, hintY),
      priority: 991,
    );
    // Set initial opacity based on animation time
    if (_startAnimationTime >= 1.0) {
      final fadeStartTime = 1.0;
      final fadeDuration = 0.2;
      final fadeProgress = ((_startAnimationTime - fadeStartTime) / fadeDuration).clamp(0.0, 1.0);
      _finger!.setOpacity(fadeProgress);
    }
    add(_finger!);
  }

  void _clearTutorialUi() {
    _dashLine?.removeFromParent();
    _finger?.removeFromParent();
    _dashLine = null;
    _finger = null;
    _tutorialLane = null;
    _isAnimating = false;
    _startAnimationTime = 0.0;
  }
}
