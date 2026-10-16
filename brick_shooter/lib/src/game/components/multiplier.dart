// lib/src/game/components/multiplier.dart
import 'dart:ui' as ui;
import 'package:flame/components.dart';

class Multiplier extends Component {
  final double width;
  final double floorY;
  final int Function() getScore;
  int _shown = 1;
  int _popLevel = 1;
  double _pop = 0;

  // Poeng som kreves for å nå neste multiplikator (2x, 3x, ...).
  // 2x kommer tidlig. Deretter tettere steg, så en god runde kan klatre videre.
  static const List<int> _thresholds = [35, 80, 140, 220, 320, 450, 620, 830, 1100, 1450];
  
  // Colors for each multiplier level (cycling through)
  static const List<ui.Color> _multiplierColors = [
    ui.Color(0xFF007AFF), // Blue for 1x
    ui.Color(0xFF00C7FF), // Cyan for 2x
    ui.Color(0xFF00FFC7), // Teal for 3x
    ui.Color(0xFF00FF7A), // Green for 4x
    ui.Color(0xFFC7FF00), // Yellow-green for 5x
    ui.Color(0xFFFFC700), // Yellow for 6x
    ui.Color(0xFFFF7A00), // Orange for 7x
  ];

  Multiplier({
    required this.width,
    required this.floorY,
    required this.getScore,
  });

  // Calculate current multiplier level (1x, 2x, 3x, etc.)
  int getCurrentMultiplier() {
    final score = getScore();
    for (int i = 0; i < _thresholds.length; i++) {
      if (score < _thresholds[i]) {
        return i + 1; // Return multiplier level (1-indexed)
      }
    }
    return _thresholds.length + 1; // Max multiplier
  }

  // Get progress for current multiplier bar (0.0 to 1.0)
  double getCurrentProgress() {
    final score = getScore();
    final multiplier = getCurrentMultiplier();
    
    if (multiplier == 1) {
      // Første steg: 0 til første terskel (2x).
      return (score / _thresholds[0]).clamp(0.0, 1.0);
    } else if (multiplier <= _thresholds.length) {
      // Subsequent bars: progress from previous threshold to current threshold
      final previousThreshold = _thresholds[multiplier - 2];
      final currentThreshold = _thresholds[multiplier - 1];
      final range = currentThreshold - previousThreshold;
      final progress = (score - previousThreshold) / range;
      return progress.clamp(0.0, 1.0);
    }
    // Max multiplier reached - bar is full
    return 1.0;
  }

  // Get color for current multiplier level
  ui.Color getCurrentColor() {
    final multiplier = getCurrentMultiplier();
    return _multiplierColors[(multiplier - 1) % _multiplierColors.length];
  }

  @override
  void render(ui.Canvas canvas) {
    final multiplier = getCurrentMultiplier();
    final progress = getCurrentProgress();
    final color = getCurrentColor();

    // Position above the line
    const lineOffset = 50.0; // Space for multiplier text and bar above the line
    final multiplierY = floorY - lineOffset;

    // Draw multiplier text with different colors for "x" and number
    // "x" is vibrant blue, number is lighter cyan
    final vibrantBlue = const ui.Color(0xFF007AFF);
    final lighterCyan = const ui.Color(0xFF00C7FF);
    
    // Build text paragraph with different colors
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: 32,
        fontWeight: ui.FontWeight.bold,
      ),
    );
    
    // Add "x" in vibrant blue
    paragraphBuilder.pushStyle(ui.TextStyle(color: vibrantBlue));
    paragraphBuilder.addText('x');
    
    // Add multiplier number in lighter cyan
    paragraphBuilder.pushStyle(ui.TextStyle(color: lighterCyan));
    paragraphBuilder.addText('$multiplier');
    
    final paragraph = paragraphBuilder.build();
    paragraph.layout(ui.ParagraphConstraints(width: double.infinity));
    
    // Center the text horizontally
    final textX = (width - paragraph.maxIntrinsicWidth) / 2;
    final textY = multiplierY - 50; // Moved higher
    
    // Draw glow effect (subtle shadow)
    final glowBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: 32,
        fontWeight: ui.FontWeight.bold,
      ),
    );
    
    glowBuilder.pushStyle(ui.TextStyle(color: vibrantBlue.withValues(alpha: 0.3)));
    glowBuilder.addText('x');
    glowBuilder.pushStyle(ui.TextStyle(color: lighterCyan.withValues(alpha: 0.3)));
    glowBuilder.addText('$multiplier');
    
    final glowParagraph = glowBuilder.build();
    glowParagraph.layout(ui.ParagraphConstraints(width: double.infinity));
    
    // Draw glow (offset slightly)
    canvas.drawParagraph(glowParagraph, ui.Offset(textX + 1, textY + 1));
    // Draw main text (centered)
    canvas.drawParagraph(paragraph, ui.Offset(textX, textY));
    _drawPop(canvas, textY);

    // Draw the fillable bar (fills from middle outward)
    const barHeight = 16.0;
    final barY = multiplierY - 14;
    final centerX = width / 2;
    
    // Draw background bar (subtle white)
    final bgPaint = ui.Paint()
      ..color = const ui.Color(0x40FFFFFF)
      ..style = ui.PaintingStyle.fill;
    canvas.drawRect(
      ui.Rect.fromLTWH(0, barY, width, barHeight),
      bgPaint,
    );

    // Draw filled portion (from center outward)
    if (progress > 0) {
      final fillPaint = ui.Paint()
        ..color = color
        ..style = ui.PaintingStyle.fill;
      
      // Fill from center outward
      final fillWidth = (width / 2) * progress;
      final leftX = centerX - fillWidth;
      
      canvas.drawRect(
        ui.Rect.fromLTWH(leftX, barY, fillWidth * 2, barHeight),
        fillPaint,
      );
    }

    // Draw the "line of death" (bright white line)
    final deathLinePaint = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF) // Bright white
      ..strokeWidth = 2.0
      ..style = ui.PaintingStyle.stroke
      ..isAntiAlias = true;
    
    canvas.drawLine(
      ui.Offset(0, floorY),
      ui.Offset(width, floorY),
      deathLinePaint,
    );
  }

  void _drawPop(ui.Canvas canvas, double textY) {
    if (_pop <= 0) return;
    final rise = (1 - _pop) * 34;
    final scale = 1.05 + (1 - _pop) * 0.35;
    final color = _multiplierColors[(_popLevel - 1) % _multiplierColors.length];
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: 40 * scale,
        fontWeight: ui.FontWeight.w800,
        textAlign: ui.TextAlign.center,
      ),
    );
    builder.pushStyle(
      ui.TextStyle(
        color: color.withValues(alpha: _pop),
        shadows: [
          ui.Shadow(color: color.withValues(alpha: _pop * 0.8), blurRadius: 16),
        ],
      ),
    );
    builder.addText('$_popLevel×');
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: width));
    canvas.drawParagraph(
      paragraph,
      ui.Offset((width - paragraph.longestLine) / 2, textY - 46 - rise),
    );
  }

  @override
  void update(double dt) {
    final now = getCurrentMultiplier();
    if (now > _shown) {
      _popLevel = now;
      _pop = 1;
    }
    _shown = now;
    if (_pop > 0) {
      _pop -= dt / 0.7;
      if (_pop < 0) _pop = 0;
    }
  }
}

