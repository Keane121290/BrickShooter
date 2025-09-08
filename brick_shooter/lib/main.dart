// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'src/game/my_game.dart';
import 'src/ui/overlays.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final game = MyGame();

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GameWidget(
        game: game,
        overlayBuilderMap: {
          MenuOverlay.id: (context, g) => MenuOverlay(game: g as MyGame),
          GameOverOverlay.id: (context, g) => GameOverOverlay(game: g as MyGame),
        },
        initialActiveOverlays: const [MenuOverlay.id],
      ),
    ),
  );
}
