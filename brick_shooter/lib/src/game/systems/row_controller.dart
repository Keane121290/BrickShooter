import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import '../components/row.dart';
import '../components/brick_box.dart';

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
    if (_isStartAnimation) {
      return _startAnimationSpeed;
    }
    if (_isDropping) {
      return _dropAnimationSpeed;
    }
    return rowSpeedPx();
  }
  
  bool get isStartAnimation => _isStartAnimation;
  
  double get startAnimationSpeed => _startAnimationSpeed;
  
  void endStartAnimation() {
    _isStartAnimation = false;
  }
  final ui.Color rowColor;

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
  bool _isDropping = false;
  double _dropAnimationSpeed = 0.0;
  double _dropTargetBottomY = 0.0;

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
        bottom.filledLanes.clear();
        bottom.reservedLanes.clear();
        bottom.pendingClear = false;
        
        // Generer ny gap-lane for denne raden
        final gapLane = _selectGapLane();
        final filled = <int>{for (int i = 0; i < lanes; i++) if (i != gapLane) i};
        bottom.filledLanes.addAll(filled);
        
        // Fjern alle eksisterende brikker ved å fjerne alle children som er BrickBox
        final childrenToRemove = bottom.children.whereType<BrickBox>().toList();
        for (final child in childrenToRemove) {
          child.removeFromParent();
        }
        
        // Legg til nye brikker for de fylte lanes
        final h = bottom.brickHeight;
        final w = bottom.brickWidth;
        final topY = -h;
        for (final lane in filled) {
          final x = lane * bottom.laneWidth + bottom.pad;
          bottom.add(
            BrickBox(color: rowColor, radius: 18, borderWidth: 3)
              ..position = Vector2(x, topY)
              ..size = Vector2(w, h)
              ..priority = 2,
          );
        }
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Oppdater drop-animasjon (scrollende effekt som startanimasjonen)
    if (_isDropping) {
      // Sjekk om den nederste raden har nådd målet
      final bottom = getBottomRow();
      if (bottom != null && bottom.bottomY >= _dropTargetBottomY) {
        // Animasjonen er ferdig
        _isDropping = false;
        _dropAnimationSpeed = 0.0;
        // Snapp alle radene til eksakt posisjon
        final offset = _dropTargetBottomY - bottom.bottomY;
        for (final row in rows) {
          if (row.isMounted) {
            row.y += offset;
            row.bottomY = row.y;
          }
        }
        ensureRowsAboveTop();
      }
      
      // Under animasjonen, sjekk kontinuerlig for overlapp og fiks dem
      // Dette forhindrer at radene overlapper mens de animerer
      _fixOverlappingRows();
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
    if (!_isStartAnimation && allowSnap && !_isDropping) {
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
      final tolerance = _isDropping ? rowHeight * 0.1 : rowHeight * 0.5;
      
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

  /// Velg **øverste hullet i første sammenhengende “fri-run” fra bunn**.
  /// Hvis nederste er blokkert i lane → bygg-under KUN hvis det er plass over gulvet.
  FallingRow landingTargetHighestInRun(int lane) {
    final col = rows.where((r) {
      if (!r.isMounted) return false;
      if (r.pendingClear) return false; // Ignore rows that are pending clear
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
    // clamp for sikkerhets skyld – aldri over gulvet, og respekter minsteplassering
    var clampedBottom = bottomY.clamp(double.negativeInfinity, floorY - 1.0);
    clampedBottom = _clampToMinimumBottomY(clampedBottom);
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

    rows.add(r);
    game.add(r);
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

  /// Sjekk om den nederste raden er over minsteplassering, og animer alle radene nedover hvis nødvendig.
  /// Dette skal kalles kontinuerlig for å sikre at den nederste raden alltid er under minsteplassering.
  /// Etter animasjon, sjekk at det er minst 6 rader over toppen og spawn nye hvis nødvendig.
  void ensureMinimumPosition() {
    if (minimumBottomY == null) return;
    
    final bottom = getBottomRow();
    if (bottom == null) return;
    
    // Hvis den nederste raden er over minsteplassering, animer alle radene nedover
    // Bruk samme scrollende effekt som startanimasjonen
    if (bottom.bottomY < minimumBottomY!) {
      if (!_isDropping) {
        _isDropping = true;

        // Beregn målposisjon og avstand
        final targetBottomY = minimumBottomY!;
        final currentBottomY = bottom.bottomY;
        final distance = targetBottomY - currentBottomY;
        
        // Bruk samme varighet som startanimasjonen (0.45 sekunder), men tredoble hastigheten
        const dropDuration = 0.45;
        _dropAnimationSpeed = (distance / dropDuration) * 3.0; // Tredoblet hastighet
        _dropTargetBottomY = targetBottomY;
        
        // Ikke bruk animateDrop() - la FallingRow.update() håndtere bevegelsen
        // ved å bruke getEffectiveSpeed() som returnerer _dropAnimationSpeed
      }
    }
  }
  
  /// Sikre at det alltid er minst 6 rader over toppen av skjermen (boardTop)
  /// Med pre-genererte 500 rader, skal dette alltid være tilfelle, men vi sjekker likevel
  void ensureRowsAboveTop() {
    // Med 500 pre-genererte rader, skal vi alltid ha nok rader over toppen
    // Denne metoden er nå primært for sikkerhetsskyld
    // Vi trenger ikke å spawn nye rader siden vi allerede har 500 pre-genererte
  }
  
  /// Hjelpemetode for å sikre at en targetBottomY respekterer minsteplassering
  double _clampToMinimumBottomY(double targetBottomY) {
    if (minimumBottomY == null) return targetBottomY;
    return targetBottomY.clamp(minimumBottomY!, double.infinity);
  }
}
