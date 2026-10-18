import 'package:brick_shooter/src/game/components/multiplier.dart';
import 'package:brick_shooter/src/game/my_game.dart';
import 'package:brick_shooter/src/game/player_profile.dart';
import 'package:brick_shooter/src/ui/overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(_phoneSurface);

  testWidgets('start and play again gently pulse', (tester) async {
    final game = _game();
    await tester.pumpWidget(MaterialApp(home: MenuOverlay(game: game)));
    await tester.pump();

    expect(find.text('Start'), findsOneWidget);
    final startBox = tester.widget<SizedBox>(
      find
          .descendant(
            of: find.byKey(const Key('menu-start')),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(startBox.height, 68);
    expect(_pulseScale(tester, const Key('menu-start')), closeTo(1, 0.001));

    await tester.pump(const Duration(milliseconds: 900));
    expect(_pulseScale(tester, const Key('menu-start')), closeTo(1.04, 0.01));

    game.score.score = 40;
    game.score.best = 40;
    await tester.pumpWidget(MaterialApp(home: GameOverOverlay(game: game)));
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.text('Play again'), findsOneWidget);
    expect(
      _pulseScale(tester, const Key('gameover-play')),
      closeTo(1.04, 0.01),
    );
  });

  testWidgets('new high score throws confetti', (tester) async {
    final game = _game();
    game.score
      ..score = 1280
      ..best = 1280
      ..newBest = true;
    await tester.pumpWidget(MaterialApp(home: GameOverOverlay(game: game)));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(const Key('highscore-confetti')), findsOneWidget);
    expect(find.text('NEW BEST'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
  });

  testWidgets('game over without a record stays quiet', (tester) async {
    final game = _game();
    game.score
      ..score = 10
      ..best = 80
      ..newBest = false;
    await tester.pumpWidget(MaterialApp(home: GameOverOverlay(game: game)));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('highscore-confetti')), findsNothing);
    expect(find.text('NEW BEST'), findsNothing);
    expect(find.text('Play again'), findsOneWidget);
    expect(find.text('THIS ROUND'), findsOneWidget);
    expect(find.textContaining('EMERALDS'), findsNothing);
    expect(find.byKey(const Key('gameover-emerald-x6')), findsNothing);
  });

  testWidgets('daily reward lists the three power-ups', (tester) async {
    final profile = PlayerProfile()..pendingDailyNotice = true;
    await tester.pumpWidget(
      MaterialApp(home: MenuOverlay(game: _game(profile))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Daily reward'), findsOneWidget);
    expect(
      find.text('A fresh set just dropped into your stash.'),
      findsOneWidget,
    );
    expect(find.text('+1'), findsNWidgets(3));
    expect(find.text('Nice!'), findsOneWidget);
  });

  testWidgets('short on emeralds offers get more or a rewarded ad', (
    tester,
  ) async {
    final profile = PlayerProfile()..emeralds = 0;
    await tester.pumpWidget(
      MaterialApp(home: MenuOverlay(game: _game(profile))),
    );
    await tester.pump();

    await tester.tap(find.text('Extra time'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Get more'), findsOneWidget);
    expect(find.text('Or'), findsOneWidget);
    expect(find.text('Add 5'), findsOneWidget);
    expect(find.byKey(const Key('power-ad-mark')), findsOneWidget);
    expect(find.text('Add 1'), findsNothing);
    expect(find.text('You have 0 emeralds'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('power-emerald-balance')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('power-get-more')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Emeralds'), findsOneWidget);
    expect(find.text('Pouch'), findsOneWidget);
    expect(find.text('Chest'), findsOneWidget);
    expect(find.text('Vault'), findsOneWidget);
    expect(find.text('30 emeralds'), findsOneWidget);
    expect(find.text('80 emeralds'), findsOneWidget);
    expect(find.text('200 emeralds'), findsOneWidget);
  });

  testWidgets('panic offers get more when the balance is short of 12', (
    tester,
  ) async {
    final profile = PlayerProfile()..emeralds = 10;
    await tester.pumpWidget(
      MaterialApp(home: MenuOverlay(game: _game(profile))),
    );
    await tester.pump();

    await tester.tap(find.text('Panic'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Get more'), findsOneWidget);
    expect(find.text('Add 5'), findsOneWidget);
    expect(find.byKey(const Key('power-ad-mark')), findsOneWidget);
    expect(find.text('Add 1'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('power-emerald-balance')),
        matching: find.text('10'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('buying a power-up spends emeralds and hides the cart', (
    tester,
  ) async {
    final profile = PlayerProfile()
      ..emeralds = 10
      ..extraTime = 2;
    await tester.pumpWidget(
      MaterialApp(home: MenuOverlay(game: _game(profile))),
    );
    await tester.pump();

    await tester.tap(find.text('Extra time'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Get more'), findsNothing);
    expect(find.text('Add 1'), findsOneWidget);
    expect(find.text('Add 5'), findsOneWidget);
    expect(find.byKey(const Key('power-ad-mark')), findsOneWidget);
    expect(find.byKey(const Key('power-buy')), findsOneWidget);
    await tester.tap(find.byKey(const Key('power-buy')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(profile.extraTime, 3);
    expect(profile.emeralds, 5);
    expect(find.text('Extra time'), findsWidgets);
    expect(find.text('Add 1'), findsOneWidget);
  });

  testWidgets('start screen keeps power-ups for use during play', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: MenuOverlay(game: _game())));
    await tester.pump();

    expect(find.text('Arm'), findsNothing);
    expect(find.text('Armed'), findsNothing);
    expect(find.text('Extra time'), findsOneWidget);
    expect(find.text('Slow-down'), findsOneWidget);
    expect(find.text('Panic'), findsOneWidget);
    expect(find.text('EMERALDS'), findsNothing);
    expect(find.text('5x'), findsNWidgets(3));
    expect(
      tester.getTopLeft(find.byKey(const Key('menu-emeralds'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('podium-1'))).dy),
    );
  });
}

MyGame _game([PlayerProfile? profile]) {
  final game = MyGame(profile: profile);
  game.multiplier = Multiplier(
    width: 390,
    floorY: 760,
    getScore: () => game.score.score,
  );
  return game;
}

void _phoneSurface() {
  final view =
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view.physicalSize = const Size(390, 844);
  view.devicePixelRatio = 1;
  addTearDown(() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
}

double _pulseScale(WidgetTester tester, Key key) {
  final transform = tester.widget<Transform>(
    find
        .descendant(of: find.byKey(key), matching: find.byType(Transform))
        .first,
  );
  return transform.transform.getMaxScaleOnAxis();
}
