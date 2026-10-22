// lib/main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';

import 'src/game/my_game.dart';
import 'src/game/player_profile.dart';
import 'src/notifications/weekly_reward_notification.dart';
import 'src/purchases/emerald_shop.dart';
import 'src/ui/overlays.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final profile = PlayerProfile();
  await profile.load();
  final shop = EmeraldShop(profile);
  await shop.start();
  final game = MyGame(profile: profile, shop: shop);

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _DailyRewardWatcher(
        profile: profile,
        onResume: game.rewardedAds.onResume,
        onPause: game.rewardedAds.onPause,
        child: GameWidget(
          game: game,
          overlayBuilderMap: {
            MenuOverlay.id: (context, g) => MenuOverlay(game: g as MyGame),
            PauseOverlay.id: (context, g) => PauseOverlay(game: g as MyGame),
            GameOverOverlay.id: (context, g) =>
                GameOverOverlay(game: g as MyGame),
          },
          initialActiveOverlays: const [MenuOverlay.id],
        ),
      ),
    ),
  );

  // First launch asks for ad consent, then a rewarded ad is loaded and kept ready.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(game.rewardedAds.initialize());
    unawaited(WeeklyRewardNotifications.sync(profile));
  });
}

class _DailyRewardWatcher extends StatefulWidget {
  const _DailyRewardWatcher({
    required this.profile,
    required this.child,
    this.onResume,
    this.onPause,
  });

  final PlayerProfile profile;
  final Widget child;
  final VoidCallback? onResume;
  final VoidCallback? onPause;

  @override
  State<_DailyRewardWatcher> createState() => _DailyRewardWatcherState();
}

class _DailyRewardWatcherState extends State<_DailyRewardWatcher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(() async {
        await widget.profile.claimWeeklyReward();
        await WeeklyRewardNotifications.sync(widget.profile);
      }());
      widget.onResume?.call();
    } else if (state == AppLifecycleState.paused) {
      widget.onPause?.call();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
