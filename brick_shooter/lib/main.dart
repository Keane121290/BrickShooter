import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'src/game/my_game.dart';
import 'src/ui/overlays.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final game = MyGame();

  runApp(
    GameWidget(
      game: game,
      overlayBuilderMap: {
        MenuOverlay.id: (context, game) => MenuOverlay(game: game as MyGame),
        GameOverOverlay.id: (context, game) => GameOverOverlay(game: game as MyGame),
      },
      initialActiveOverlays: const [MenuOverlay.id],
    ),
  );
}
