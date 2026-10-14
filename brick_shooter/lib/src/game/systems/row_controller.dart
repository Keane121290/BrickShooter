import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import '../components/row.dart';
import '../config.dart';

/// Kontrollerer rader:
/// - Spawner alltid 3 brikker + 1 hull (deterministisk)
/// - Targeting: øverste hull i første “fri-run” fra bunn; bygg-under KUN hvis det er plass
/// - Sorterer nederst→øverst for stabil logikk
class RowController extends Component with HasGameReference<FlameGame> {
  final List<FallingRow> rows = [];

  final double boardTop;
  final double floorY;
  final int lanes;
  final double laneWidth, rowHeight, padPx;
  final double Function() rowSpeedPx; // brukes av FallingRow via getSpeed
  
  double getEffectiveSpeed() {
    final base = _isStartAnimation
        ? _startAnimationSpeed
        : rowSpeedPx() + _catchUpSpeed;
    return base * speedScale;
  }

  /// 1 er normal fart. Slow-down setter denne lavere i noen sekunder.
  double speedScale = 1;
  
  bool get isStartAnimation => _isStartAnimation;
  
  double get startAnimationSpeed => _startAnimationSpeed;
  
  void endStartAnimation() {
    _isStartAnimation = false;
  }
  final ui.Color rowColor;

  static const _specialColor = ui.Color(0xFFFF2D3A);
  static const _candyColors = <ui.Color>[
    ui.Color(0xFFFF6EC7),
    ui.Color(0xFF5FD0FF),
    ui.Color(0xFFB388FF),
    ui.Color(0xFF6DFFB0),
    ui.Color(0xFFFFC45A),
    ui.Color(0xFFFFF06A),
  ];

  int _nextRowNumber = 1;
  double cottonCandyLeft = 0;
  double candyClock = 0;

  bool get cottonCandyActive => cottonCandyLeft > 0;

  /// Minsteplassering for den nederste raden (stopY fra rød linje)
  double? minimumBottomY;

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
  bool _isStartAnimation = false;
  double _startAnimationSpeed = 0.0;

  /// Ekstra fart som henter stabelen ned når spilleren rydder raskere enn den faller.
  double _catchUpSpeed = 0.0;

  static const int minVisibleRows = 4;

  int? _nextForcedGap; // debug-hook
  
  // Spor de siste gap-lanes for å unngå 4 rader på rad med samme åpne kolonne
  final List<int> _recentGapLanes = [];

  void forceNextGap(int holeLaneIndex) {
    _nextForcedGap = holeLaneIndex.clamp(0, lanes - 1);
  }

  double _gridBottomForIndex(int idx) => boardTop + idx * rowHeight;
  double get spawnBottomY => _gridBottomForIndex(-1);

  /// Velger en gap-lane som ikke har vært åpen 3 ganger på rad.
  /// Returnerer en tilfeldig lane, men ekskluderer lanes som har vært åpne 3 ganger på rad.
  int _selectGapLane() {
    if (_nextForcedGap != null) {
      final forced = _nextForcedGap!;
      _nextForcedGap = null;
      _recentGapLanes.add(forced);
      // Hold kun de siste 3
      if (_recentGapLanes.length > 3) {
        _recentGapLanes.removeAt(0);
      }
      return forced;
    }

    // Sjekk om noen lane har vært åpen 3 ganger på rad
    Set<int> forbiddenLanes = {};
    if (_recentGapLanes.length >= 3) {
      final lastThree = _recentGapLanes.sublist(_recentGapLanes.length - 3);
      // Hvis alle tre er like, er den lane forbudt
      if (lastThree[0] == lastThree[1] && lastThree[1] == lastThree[2]) {
        forbiddenLanes.add(lastThree[0]);
      }
    }

    // Velg tilfeldig lane, men ekskluder forbudte lanes
    List<int> availableLanes = [];
    for (int i = 0; i < lanes; i++) {
      if (!forbiddenLanes.contains(i)) {
        availableLanes.add(i);
      }
    }

    // Hvis alle lanes er forbudt (skulle ikke skje), bruk alle lanes
    if (availableLanes.isEmpty) {
      availableLanes = List.generate(lanes, (i) => i);
    }

    final selectedLane = availableLanes[_rng.nextInt(availableLanes.length)];
    
    // Legg til i historikk
    _recentGapLanes.add(selectedLane);
    // Hold kun de siste 3
    if (_recentGapLanes.length > 3) {
      _recentGapLanes.removeAt(0);
    }
    
    return selectedLane;
  }

  // Init synlige + prebuffer rader over toppen (for start-animasjon)
  void spawnInitialAboveTop({
    required int visible,
    required int prebuffer,
  }) {
    for (final r in rows) {
      r.removeFromParent();
    }
    rows.clear();
    _recentGapLanes.clear();
    _resetSpecials();
    _catchUpSpeed = 0;

    // Spawn rader over toppen med riktig spacing
    final startOffset = rowHeight * (visible + 2); // Start godt over toppen
    final firstRowStartY = boardTop - startOffset;
    
    for (int i = 0; i < visible; i++) {
      final startBottom = firstRowStartY + i * rowHeight;
      _spawnGapLikeRowAtBottomY(startBottom);
    }
    
    // Spawn prebuffer rader også over toppen
    for (int i = prebuffer; i >= 1; i--) {
      final startBottom = firstRowStartY - (prebuffer - i + 1) * rowHeight;
      _spawnGapLikeRowAtBottomY(startBottom);
    }
  }

  // Init synlige + prebuffer rader
  void spawnInitial({
    required int visible,
    required int prebuffer,
    double? startAnimationTargetY,
    double? startAnimationDuration,
  }) {
    for (final r in rows) {
      r.removeFromParent();
    }
    rows.clear();
    _recentGapLanes.clear();
    _resetSpecials();
    _catchUpSpeed = 0;

    // Pre-generer 500 rader i en lang rekke over toppen
    const totalRows = 500;
    
    // Start-animasjon: den nederste raden starter fra toppen av skjermen og beveger seg nedover
    if (startAnimationTargetY != null && startAnimationDuration != null) {
      _isStartAnimation = true;
      
      // Den nederste raden skal starte på boardTop og bevege seg nedover til startAnimationTargetY
      final lastRowStartY = boardTop; // Nederste rad starter på toppen av skjermen
      final lastRowTargetY = startAnimationTargetY; // Nederste rad stopper på startlinjen
      
      // Beregn hastighet basert på den nederste raden
      final distance = lastRowTargetY - lastRowStartY;
      _startAnimationSpeed = distance / startAnimationDuration;
      
      // Pre-generer alle 500 rader med riktig spacing
      // Den nederste raden starter på boardTop, resten plasseres over med rowHeight spacing
      for (int i = 0; i < totalRows; i++) {
        // Den nederste raden (i=0) starter på boardTop
        // De andre radene plasseres over med rowHeight spacing
        final startBottom = lastRowStartY - (i * rowHeight);
        _spawnGapLikeRowAtBottomY(startBottom);
      }
    } else {
      // Normal spawn (ingen animasjon) - pre-generer alle 500 rader
      _isStartAnimation = false;
      
      // Plasser alle 500 rader over toppen med korrekt spacing
      // Den nederste raden starter på boardTop
      for (int i = 0; i < totalRows; i++) {
        final startBottom = boardTop - (i * rowHeight);
        _spawnGapLikeRowAtBottomY(startBottom);
      }
    }
  }

  void _spawnGapLikeRowAtBottomY(double targetBottom) {
    // Under start-animasjonen, ikke snapp til grid - bruk eksakt posisjon
    // I playing fase, bruk også eksakt posisjon for å unngå hakking
    // Snapp kun til grid i tutorialHold fase eller når radene skal stoppe
    final snappedBottom = _isStartAnimation 
        ? targetBottom 
        : targetBottom; // Bruk eksakt posisjon, ikke snapp til grid
    
    // Ikke spawn hvis rad ligger nær samme nivå (hindrer skyggerader)
    final existing = findRowNearBottom(snappedBottom, eps: rowHeight * 0.45);
    if (existing != null) return;

    // Nøyaktig 1 hull (gapLane) - bruk logikk som unngår 4 rader på rad i samme kolonne
    final gapLane = _selectGapLane();

    final filled = <int>{for (int i = 0; i < lanes; i++) if (i != gapLane) i};

    final r = FallingRow(
      lanes: lanes,
      laneWidth: laneWidth,
      rowHeight: rowHeight,
      pad: padPx,
      bottomY: snappedBottom,
      getSpeed: () => getEffectiveSpeed(),
      color: rowColor,
      filledLanes: filled,
    )..priority = 50;

    _stamp(r, counted: true);
    rows.add(r);
    game.add(r);
  }

  // Recycling: flytt rader som går ut av skjermen tilbake til toppen
  // Siden vi har pre-generert 500 rader, trenger vi ikke spawn nye - vi recycler eksisterende
  void tickSpawn(double dt) {
    final v = rowSpeedPx();
    if (v <= 0) return;

    // Sjekk om noen rader har gått ut av skjermen nederst og trenger å flyttes tilbake til toppen
    final bottom = getBottomRow();
    final top = getTopRow();
    
    if (bottom != null && top != null) {
      // Hvis den nederste raden har gått ut av skjermen (under floorY eller langt under minimumBottomY)
      // Flytt den til toppen
      if (bottom.bottomY > floorY + rowHeight * 2) {
        // Flytt denne raden til toppen
        final newBottomY = top.bottomY - rowHeight;
        bottom.y = newBottomY;
        bottom.bottomY = newBottomY;
        
        // Reset radens tilstand (fjern alle brikker og reservasjoner)
        bottom.clearSway();
        bottom.filledLanes.clear();
        bottom.reservedLanes.clear();
        bottom.pendingClear = false;

        final gapLane = _selectGapLane();
        final filled = <int>{for (int i = 0; i < lanes; i++) if (i != gapLane) i};
        bottom.filledLanes.addAll(filled);
        _stamp(bottom, counted: true);
        bottom.rebuildBricks();
      }
    }
  }

  // Sorter nederst→øverst (størst bottomY først)
  void maintenanceDedupeAndSnap({bool allowSnap = true}) {
    if (rows.length < 2) return;
    rows.sort((a, b) => b.bottomY.compareTo(a.bottomY));
    
    // Alltid sjekk for overlappende rader, selv under animasjoner
    // Dette forhindrer at radene overlapper mens de animerer eller beveger seg
    _fixOverlappingRows();
    
    // Under start-animasjonen, ikke snapp til grid - la radene bevege seg fritt
    // I tutorialDrop fase (etter start-animasjonen), la radene også bevege seg fritt
    // Snapp kun til grid når radene skal stoppe (tutorialHold) eller når de overlapper
    // Ikke snapp hvis drop-animasjonen pågår
    if (!_isStartAnimation && allowSnap) {
      // Kun snapp hvis radene faktisk overlapper eller er for langt unna grid
      _snapRowsToGrid();
    }
  }
  
  /// Snapp alle rader til nærmeste grid-posisjon for å unngå overlapp
  /// Dette skal kun brukes når radene skal stoppe (tutorialHold) eller etter drop-animasjoner
  void _snapRowsToGrid() {
    // Først sjekk for overlappende rader og korriger dem
    // Dette er viktig for å unngå overlapp
    _fixOverlappingRows();
    
    // Deretter snapp radene til grid hvis de er for langt unna
    // Men kun hvis de faktisk trenger det (ikke når de beveger seg kontinuerlig)
    // Bruk en stor toleranse for å unngå vibrasjon
    for (final row in rows) {
      if (!row.isMounted) continue;
      
      // Beregn nærmeste grid-posisjon basert på rowHeight
      // Grid-posisjoner er multipler av rowHeight fra boardTop
      final gridIndex = ((row.bottomY - boardTop) / rowHeight).round();
      final snappedBottomY = boardTop + (gridIndex * rowHeight);
      
      // Snapp til grid kun hvis avstanden er større enn en stor toleranse (50% av rowHeight)
      // Dette forhindrer at radene snappes hver frame når de beveger seg kontinuerlig
      // Men la radene bevege seg fritt i playing fase
      if ((row.bottomY - snappedBottomY).abs() > rowHeight * 0.5) {
        row.y = snappedBottomY;
        row.bottomY = snappedBottomY;
      }
    }
  }
  
  /// Fikse overlappende rader ved å flytte dem til korrekt grid-posisjon
  void _fixOverlappingRows() {
    // Sorter radene etter bottomY (nederst først)
    final sortedRows = rows.where((r) => r.isMounted).toList()
      ..sort((a, b) => a.bottomY.compareTo(b.bottomY));
    
    for (int i = 0; i < sortedRows.length - 1; i++) {
      final currentRow = sortedRows[i];
      final nextRow = sortedRows[i + 1];
      
      // Sjekk om radene overlapper (mindre enn rowHeight mellom dem)
      // Under drop-animasjonen, bruk mindre toleranse for å fikse overlapp raskere
      final distance = nextRow.bottomY - currentRow.bottomY;
      final tolerance = rowHeight * 0.5;
      
      if (distance < rowHeight - tolerance) {
        // Flytt neste rad til korrekt posisjon (en rowHeight over nåværende)
        final correctBottomY = currentRow.bottomY + rowHeight;
        
        // Under drop-animasjon bruker vi kontinuerlig hastighet, så vi kan flytte umiddelbart
        // Dette fungerer også under normal bevegelse
        nextRow.y = correctBottomY;
        nextRow.bottomY = correctBottomY;
      }
    }
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

  /// Finn den øverste raden (lavest bottomY)
  FallingRow? getTopRow() {
    if (rows.isEmpty) return null;
    FallingRow? top;
    double minY = double.infinity;
    for (final r in rows) {
      if (!r.isMounted) continue;
      if (r.bottomY < minY) {
        minY = r.bottomY;
        top = r;
      }
    }
    return top;
  }

  bool isBottomRow(FallingRow row) => identical(getBottomRow(), row);

  FallingRow? findRowNearBottom(double desiredBottom, {double eps = 1.6}) {
    for (final r in rows) {
      if (!r.isMounted) continue;
      if ((r.bottomY - desiredBottom).abs() <= eps) return r;
    }
    return null;
  }

  /// Find the row directly above the given row (one rowHeight above)
  FallingRow? findRowAbove(FallingRow row) {
    if (!row.isMounted) return null;
    final targetBottomY = row.bottomY - rowHeight; // Row above should be one rowHeight up
    return findRowNearBottom(targetBottomY, eps: rowHeight * 0.5);
  }

  /// Land i det øverste hullet i sammenhengende åpne rader, telt fra bunnen.
  /// En fylt eller reservert kolonne stopper løpet. Er bunnen fylt, legg en ny rad rett under.
  FallingRow landingTargetHighestInRun(int lane) {
    final col = rows.where((r) => r.isMounted).toList()
      ..sort((a, b) => b.bottomY.compareTo(a.bottomY)); // nederst → øverst

    if (col.isEmpty) {
      return _ensureRowAtBottomY(restingBottomY);
    }

    final bottom = col.first;
    final bottomBlocked =
        bottom.filledLanes.contains(lane) || bottom.reservedLanes.contains(lane);

    if (bottomBlocked) {
      // vurder om det er plass til en ny rad under
      final nextBottom = bottom.bottomY + rowHeight;
      // liten sikkerhetsmargin så vi ikke "spawner i gulvet"
      final safeBottomMax = floorY - rowHeight * 0.25;
      if (nextBottom <= safeBottomMax) {
        return _ensureRowAtBottomY(nextBottom);
      } else {
        // ikke plass: ikke bygg-under – skuddet vil ikke reservere og blir ignorert
        return bottom; // reserve() vil feile fordi lane er blokkert
      }
    }

    // Åpne hull rett over hverandre: legg skuddet i det øverste.
    // En full rad blir stående til raden under også er full.
    FallingRow lastFree = bottom;
    for (int i = 1; i < col.length; i++) {
      final r = col[i];
      final separated = (lastFree.bottomY - r.bottomY - rowHeight).abs();
      if (separated > rowHeight * 0.45) break;
      final blocked =
          r.filledLanes.contains(lane) || r.reservedLanes.contains(lane);
      if (blocked) break;
      lastFree = r;
    }
    return lastFree;
  }

  FallingRow _ensureRowAtBottomY(double bottomY) {
    // Rett under stabelen. Ikke dra raden ned til minimumslinjen, det lager et hull.
    final safeBottomMax = floorY - rowHeight * 0.25;
    final clampedBottom = bottomY > safeBottomMax ? safeBottomMax : bottomY;
    final existing = findRowNearBottom(clampedBottom, eps: rowHeight * 0.45);
    if (existing != null) return existing;

    final r = FallingRow(
      lanes: lanes,
      laneWidth: laneWidth,
      rowHeight: rowHeight,
      pad: padPx,
      bottomY: clampedBottom,
      getSpeed: () => getEffectiveSpeed(),
      color: rowColor,
      filledLanes: {},
    )..priority = 50;

    _stamp(r, counted: false);
    rows.add(r);
    game.add(r);
    return r;
  }

  void _resetSpecials() {
    _nextRowNumber = 1;
    cottonCandyLeft = 0;
    candyClock = 0;
  }

  ui.Color restingColorFor(int rowNumber) {
    if (rowNumber > 0 && rowNumber % GameConfig.specialRowEvery == 0) {
      return _specialColor;
    }
    return rowColor;
  }

  ui.Color candyColorFor(int key) {
    final index = key.abs() % _candyColors.length;
    return _candyColors[index];
  }

  void _stamp(FallingRow row, {required bool counted}) {
    if (counted) {
      row.rowNumber = _nextRowNumber++;
    }
    row.restingColor = restingColorFor(row.rowNumber);
    row.color = cottonCandyActive ? candyColorFor(row.rowNumber) : row.restingColor;
  }

  /// Fargelegg alle rader og la klossene sjangre sidelengs mens effekten varer.
  void tickCottonCandy(double dt) {
    if (cottonCandyLeft <= 0) return;
    cottonCandyLeft -= dt;
    candyClock += dt;
    if (cottonCandyLeft <= 0) {
      cottonCandyLeft = 0;
      for (final row in rows) {
        row.clearSway();
        row.recolor(row.restingColor);
      }
      return;
    }
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final key = row.rowNumber > 0 ? row.rowNumber : i + 1;
      row.recolor(candyColorFor(key));
      row.applySway(candyClock);
    }
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
      if (bottom.isSpecial) {
        cottonCandyLeft = GameConfig.cottonCandySeconds;
      }
      _removeRow(bottom);
      cleared++;
    }
    return cleared;
  }

  void _removeRow(FallingRow r) {
    r.removeFromParent();
    rows.remove(r);
  }

  /// Fjerner radene som vises på brettet. Brukes av panic.
  int clearVisibleRows({required void Function(FallingRow row) onExplode}) {
    final visible = rows.where((r) {
      if (!r.isMounted) return false;
      final top = r.bottomY - r.brickHeight;
      return r.bottomY > boardTop && top < floorY;
    }).toList();
    var special = false;
    for (final row in visible) {
      onExplode(row);
      if (row.isSpecial) special = true;
      _removeRow(row);
    }
    if (special) {
      cottonCandyLeft = GameConfig.cottonCandySeconds;
    }
    return visible.length;
  }

  /// Der den nederste raden skal ligge for at fire hele rader er på skjermen.
  double get restingBottomY {
    final brickH = rowHeight - 2 * padPx;
    final fourRows = boardTop + (minVisibleRows - 1) * rowHeight + brickH;
    final minLine = minimumBottomY ?? fourRows;
    final cap = floorY - rowHeight;
    return min(max(minLine, fourRows), cap);
  }

  /// Hent stabelen ned mot [restingBottomY]. Farten regnes på nytt hver frame
  /// ut fra hvor stort hullet er, så rask rydning gir raskere innhenting.
  void ensureMinimumPosition(double dt) {
    final bottom = getBottomRow();
    if (bottom == null) {
      _catchUpSpeed = 0;
      return;
    }

    final gap = restingBottomY - bottom.bottomY;
    if (gap <= 0.5) {
      _catchUpSpeed = 0;
      return;
    }

    final gapRows = gap / rowHeight;
    final duration = (0.16 + gapRows * 0.05).clamp(0.16, 0.55);
    final normal = max(0.0, rowSpeedPx());
    final desiredExtra = max(0.0, gap / duration - normal);
    final blend = dt <= 0 ? 1.0 : (1 - exp(-dt * 12)).clamp(0.0, 1.0);
    _catchUpSpeed += (desiredExtra - _catchUpSpeed) * blend;

    final maxTotal = gap / max(dt, 0.001);
    if (normal + _catchUpSpeed > maxTotal) {
      _catchUpSpeed = max(0.0, maxTotal - normal);
    }
  }
}
