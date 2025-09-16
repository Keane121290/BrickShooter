import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import '../components/row.dart';

/// Kontrollerer rader:
/// - Spawner alltid 3 brikker + 1 hull (deterministisk)
/// - “Build-under” når nederste rad er blokkert i aktuell kolonne
/// - Vedlikehold mot overlapp (dedupe/sort)
class RowController extends Component with HasGameRef<FlameGame> {
  final List<FallingRow> rows = [];

  final double boardTop;
  final double floorY;
  final int lanes;
  final double laneWidth, rowHeight, padPx;
  final double Function() rowSpeedPx; // brukes av FallingRow via getSpeed
  final ui.Color rowColor;

  RowController({
    required this.boardTop,
    required this.floorY,
    required this.lanes,
    required this.laneWidth,
    required this.rowHeight,
    required this.padPx,
    required this.rowSpeedPx,
    required this.rowColor,
  });

  final _rng = Random();
  double _spawnAccumPx = 0;

  int? _nextForcedGap; // debug-hook

  void forceNextGap(int holeLaneIndex) {
    _nextForcedGap = holeLaneIndex.clamp(0, lanes - 1);
  }

  double _gridTopForIndex(int idx) => boardTop + idx * rowHeight;
  double _gridBottomForIndex(int idx) =>
      _gridTopForIndex(idx) + (rowHeight - 2 * padPx);
  double get spawnBottomY => _gridBottomForIndex(-1);

  // Init synlige + prebuffer rader
  void spawnInitial({required int visible, required int prebuffer}) {
    for (final r in rows) {
      r.removeFromParent();
    }
    rows.clear();
    _spawnAccumPx = 0;

    for (int i = 0; i < visible; i++) {
      _spawnGapLikeRowAtGridIndex(i);
    }
    for (int i = prebuffer; i >= 1; i--) {
      _spawnGapLikeRowAtGridIndex(-i);
    }
  }

  // Kun “spawn etter distanse” – ingen flytting; FallingRow.update() håndterer bevegelsen
  void tickSpawn(double dt) {
    final v = rowSpeedPx();
    if (v <= 0) return;

    _spawnAccumPx += v * dt;
    if (_spawnAccumPx >= rowHeight) {
      _spawnAccumPx -= rowHeight;
      _spawnGapLikeRowAtGridIndex(-1);
    }
  }

  void _spawnGapLikeRowAtGridIndex(int gridIndex) {
    final targetBottom = _gridBottomForIndex(gridIndex);

    // Ikke spawn hvis rad ligger nær samme nivå (hindrer skyggerader)
    final existing = findRowNearBottom(targetBottom, eps: rowHeight * 0.45);
    if (existing != null) return;

    // Nøyaktig 1 hull (gapLane)
    final gapLane = _nextForcedGap ?? _rng.nextInt(lanes);
    _nextForcedGap = null;

    final filled = <int>{for (int i = 0; i < lanes; i++) if (i != gapLane) i};

    final r = FallingRow(
      lanes: lanes,
      laneWidth: laneWidth,
      rowHeight: rowHeight,
      pad: padPx,
      bottomY: targetBottom,
      getSpeed: rowSpeedPx,
      color: rowColor,
      filledLanes: filled,
    )..priority = 50;

    rows.add(r);
    gameRef.add(r);
  }

  // Vedlikehold: bare sorter nederst→øverst (vi slo tidligere sammen tette rader – kan aktiveres ved behov)
  void maintenanceDedupeAndSnap() {
    if (rows.length < 2) return;
    rows.sort((a, b) => b.bottomY.compareTo(a.bottomY)); // nederst først
  }

  FallingRow? getBottomRow() {
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

  bool isBottomRow(FallingRow row) => identical(getBottomRow(), row);

  FallingRow? findRowNearBottom(double desiredBottom, {double eps = 1.6}) {
    for (final r in rows) {
      if (!r.isMounted) continue;
      if ((r.bottomY - desiredBottom).abs() <= eps) return r;
    }
    return null;
  }

  /// Velg **øverste hullet i første sammenhengende “fri-run” fra bunn**;
  /// hvis nederste er blokkert i lane → bygg under.
  FallingRow landingTargetHighestInRun(int lane) {
    final col = rows.where((r) {
      if (!r.isMounted) return false;
      final brickH = r.brickHeight;
      final top = r.bottomY - brickH;
      return r.bottomY >= (boardTop - rowHeight) && top <= floorY;
    }).toList()
      ..sort((a, b) => b.bottomY.compareTo(a.bottomY)); // nederst → øverst

    if (col.isEmpty) {
      return _ensureRowAtBottomY(spawnBottomY);
    }

    final bottom = col.first;
    final bottomBlocked =
        bottom.filledLanes.contains(lane) || bottom.reservedLanes.contains(lane);

    if (bottomBlocked) {
      // blokkerer passasje → bygg under
      return _ensureRowAtBottomY(bottom.bottomY + rowHeight);
    }

    // bunn er fri → gå oppover mens lane er fri; velg høyeste i “run”
    FallingRow lastFree = bottom;
    for (int i = 1; i < col.length; i++) {
      final r = col[i];
      final blocked =
          r.filledLanes.contains(lane) || r.reservedLanes.contains(lane);
      if (blocked) break;
      lastFree = r;
    }
    return lastFree;
  }

  FallingRow _ensureRowAtBottomY(double bottomY) {
    final existing = findRowNearBottom(bottomY, eps: rowHeight * 0.45);
    if (existing != null) return existing;

    final r = FallingRow(
      lanes: lanes,
      laneWidth: laneWidth,
      rowHeight: rowHeight,
      pad: padPx,
      bottomY: bottomY,
      getSpeed: rowSpeedPx,
      color: rowColor,
      filledLanes: {},
    )..priority = 50;

    rows.add(r);
    gameRef.add(r);
    return r;
  }

  bool reserve(FallingRow row, int lane, {ui.Color? ghostColor}) {
    return row.reserveLane(lane, ghostColor: ghostColor);
  }

  bool fill(FallingRow row, int lane) {
    return row.fillLane(lane);
  }

  void unreserve(FallingRow row, int lane) {
    row.unreserveLane(lane);
  }

  int clearBottomIfPending({required void Function(FallingRow row) onExplode}) {
    int cleared = 0;
    while (true) {
      final bottom = getBottomRow();
      if (bottom == null) break;
      if (!bottom.pendingClear) break;
      onExplode(bottom);
      _removeRow(bottom);
      cleared++;
    }
    return cleared;
  }

  void _removeRow(FallingRow r) {
    r.removeFromParent();
    rows.remove(r);
  }
}
