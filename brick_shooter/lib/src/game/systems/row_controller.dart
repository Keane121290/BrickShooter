import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import '../components/row.dart';

class RowController extends Component {
  final List<FallingRow> rows = [];

  final double boardTop;
  final double floorY;
  final int lanes;
  final double laneWidth, rowHeight, padPx;
  final double Function() rowSpeedPx; // injiseres fra DifficultyController
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

  // --- Grid helpers ---
  double _gridTopForIndex(int idx) => boardTop + idx * rowHeight;
  double _gridBottomForIndex(int idx) => _gridTopForIndex(idx) + (rowHeight - 2 * padPx);
  double get spawnBottomY => _gridBottomForIndex(-1);

  // --- Spawning ---
  void spawnInitial({required int visible, required int prebuffer}) {
    // synlige indekser fra 0..visible-1
    for (int i = 0; i < visible; i++) {
      _spawnGapLikeRowAtGridIndex(i);
    }
    // prebuffer over skjerm: -prebuffer..-1
    for (int i = prebuffer; i >= 1; i--) {
      _spawnGapLikeRowAtGridIndex(-i);
    }
  }

  void tickSpawn(double dt) {
    _spawnAccumPx += rowSpeedPx() * dt;
    while (_spawnAccumPx >= rowHeight) {
      _spawnAccumPx -= rowHeight;
      _spawnGapLikeRowAtGridIndex(-1);
    }
  }

  void _spawnGapLikeRowAtGridIndex(int gridIndex) {
    // én lane er hull; tre er fylt
    final gapLane = _rng.nextInt(lanes);
    final filled = <int>{for (int i = 0; i < lanes; i++) if (i != gapLane) i};

    final r = FallingRow(
      lanes: lanes,
      laneWidth: laneWidth,
      rowHeight: rowHeight,
      pad: padPx,
      bottomY: _gridBottomForIndex(gridIndex),
      getSpeed: rowSpeedPx,
      color: rowColor,
      filledLanes: filled,
    );
    rows.add(r);
    add(r);
  }

  // --- Bottom clear (deterministisk, sammenhengende) ---
  /// Fjerner alle sammenhengende fulle bunnrader (de som allerede er merket pendingClear).
  /// Returnerer hvor mange rader som ble fjernet.
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

  // --- Query / util ---
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

  /// Finn første lovlige mål FRA BUNN i kolonne. Stopper på blokkering (fylt eller reservert).
  FallingRow? firstLegalTarget(int lane) {
    // synlige rader, nederst -> øverst
    final col = rows.where((r) {
      if (!r.isMounted) return false;
      final top = r.bottomY - (rowHeight - 2 * padPx);
      return r.bottomY >= boardTop && top <= floorY;
    }).toList()
      ..sort((a, b) => a.bottomY.compareTo(b.bottomY));

    for (final r in col) {
      final isFilled = r.filledLanes.contains(lane);
      final isReserved = r.reservedLanes.contains(lane);
      if (isFilled || isReserved) {
        return null; // blokkering: ingen høyere hull lovlig
      }
      if (r.hasFreeLane(lane)) {
        return r; // første ledige under blokkering
      }
    }
    return null;
  }

  // --- Reserve/fill/unreserve ---
  bool reserve(FallingRow row, int lane, {ui.Color? ghostColor}) {
    return row.reserveLane(lane, ghostColor: ghostColor);
  }

  /// Fyll lane i row. Returnerer om raden ble full (da settes pendingClear=true i MyGame).
  bool fill(FallingRow row, int lane) {
    return row.fillLane(lane);
  }

  void unreserve(FallingRow row, int lane) {
    row.unreserveLane(lane);
  }

  /// Reservér på topp: hvis rad finnes på spawnBottomY, reserver der – ellers opprett ny.
  FallingRow reserveOnTop(int lane, {required ui.Color ghostColor}) {
    final existing = findRowNearBottom(spawnBottomY, eps: 1.6);
    if (existing != null) {
      existing.reserveLane(lane, ghostColor: ghostColor);
      return existing;
    }
    final r = FallingRow(
      lanes: lanes,
      laneWidth: laneWidth,
      rowHeight: rowHeight,
      pad: padPx,
      bottomY: spawnBottomY,
      getSpeed: rowSpeedPx,
      color: rowColor,
      filledLanes: {},
    );
    r.reserveLane(lane, ghostColor: ghostColor);
    rows.add(r);
    add(r);
    return r;
  }

  // --- Internal ---
  void _removeRow(FallingRow r) {
    r.removeFromParent();
    rows.remove(r);
  }
}
