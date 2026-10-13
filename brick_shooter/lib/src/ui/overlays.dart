// lib/src/ui/overlays.dart
import 'package:flutter/material.dart';
import '../game/my_game.dart';

class MenuOverlay extends StatelessWidget {
  static const id = 'menu';
  final MyGame game;
  const MenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Brick Shooter',
                    style: TextStyle(fontSize: 32, color: Colors.white)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => game.startGame(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF53D769),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Start', style: TextStyle(fontSize: 20)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GameOverOverlay extends StatefulWidget {
  static const id = 'gameover';
  final MyGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    final curved = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    _fade = curved;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
      children: [
        const ModalBarrier(
          color: Color(0xC0101820),
          dismissible: false,
        ),
        Center(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: _GameOverCard(
                score: game.score.score,
                best: game.score.best,
                isNewBest: game.score.newBest,
                multiplier: game.multiplier.getCurrentMultiplier(),
                onPlayAgain: game.startGame,
                onMenu: game.backToMenu,
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }
}

class _GameOverCard extends StatelessWidget {
  final int score;
  final int best;
  final bool isNewBest;
  final int multiplier;
  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;

  const _GameOverCard({
    required this.score,
    required this.best,
    required this.isNewBest,
    required this.multiplier,
    required this.onPlayAgain,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xF01E3542), Color(0xF0121C24)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF2A6E96), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                blurRadius: 32,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _BrickRow(),
                const SizedBox(height: 18),
                const Text(
                  'Game over',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _formatScore(score),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w800,
                    height: 0.95,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'POINTS',
                  style: TextStyle(
                    color: Color(0xFF9BB4C2),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                  ),
                ),
                if (isNewBest) ...[
                  const SizedBox(height: 14),
                  const _NewBestChip(),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'BEST',
                        value: _formatScore(best),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        label: 'MULTIPLIER',
                        value: '×$multiplier',
                        valueColor: _multiplierColor(multiplier),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: onPlayAgain,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF53D769),
                      foregroundColor: const Color(0xFF102016),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('Play again'),
                  ),
                ),
                TextButton(
                  onPressed: onMenu,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD5E4EC),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Menu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrickRow extends StatelessWidget {
  const _BrickRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MiniBrick(color: Color(0xFF1A7AB8)),
        SizedBox(width: 6),
        _MiniBrick(color: Color(0xFF1A7AB8)),
        SizedBox(width: 6),
        _GapBrick(),
        SizedBox(width: 6),
        _MiniBrick(color: Color(0xFF53D769)),
      ],
    );
  }
}

class _MiniBrick extends StatelessWidget {
  final Color color;
  const _MiniBrick({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x66FFFFFF), width: 1.5),
      ),
    );
  }
}

class _GapBrick extends StatelessWidget {
  const _GapBrick();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 22,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x66FFFFFF), width: 1.5),
      ),
    );
  }
}

class _NewBestChip extends StatelessWidget {
  const _NewBestChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x3353D769),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF53D769)),
      ),
      child: const Text(
        'NEW BEST',
        style: TextStyle(
          color: Color(0xFF53D769),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatTile({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x33101820),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x332E6F9A)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9BB4C2),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatScore(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('\u2009');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

Color _multiplierColor(int level) {
  const colors = [
    Color(0xFF7EC8FF),
    Color(0xFF5EE7FF),
    Color(0xFF5DFFD6),
    Color(0xFF7DFF6A),
    Color(0xFFE4FF5A),
    Color(0xFFFFD15A),
    Color(0xFFFF9A3C),
  ];
  final index = (level - 1).clamp(0, colors.length - 1).toInt();
  return colors[index];
}
