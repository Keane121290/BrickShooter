import 'package:flutter/material.dart';
import '../game/my_game.dart';

class MenuOverlay extends StatelessWidget {
  static const id = 'MenuOverlay';
  final MyGame game;
  const MenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: Stack(
        children: [
          Container(color: Colors.black54),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('BRICK SHOOTER',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text('Best score: ${game.bestScore}'),
                      const SizedBox(height: 4),
                      const Text('Trykk på en av de fire banene for å skyte. '
                          'Treff hullet i raden!'),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: game.startGame,
                        child: const Text('Start'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GameOverOverlay extends StatelessWidget {
  static const id = 'GameOverOverlay';
  final MyGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: Stack(
        children: [
          Container(color: Colors.black54),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('GAME OVER',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text('Score: ${game.score}'),
                      Text('Best: ${game.bestScore}'),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: game.backToMenu,
                            child: const Text('Meny'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: game.startGame,
                            child: const Text('Spill igjen'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
