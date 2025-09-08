// lib/src/ui/overlays.dart
import 'package:flutter/material.dart';
import '../game/my_game.dart';

class MenuOverlay extends StatelessWidget {
  static const id = 'menu';
  final MyGame game;
  const MenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Stack(
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
    );
  }
}

class GameOverOverlay extends StatelessWidget {
  static const id = 'gameover';
  final MyGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xCC0F1115),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Game Over — score: ${game.score}',
                  style: const TextStyle(fontSize: 22, color: Colors.white)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => game.startGame(),
                child: const Text('Restart'),
              ),
              TextButton(
                onPressed: () => game.backToMenu(),
                child: const Text('Back to menu'),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
