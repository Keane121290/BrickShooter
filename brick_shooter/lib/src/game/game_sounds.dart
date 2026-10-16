import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

import 'player_profile.dart';

/// Short effects: a shot, a row clear, and game over.
class GameSounds {
  GameSounds(this.profile);

  final PlayerProfile profile;

  static const shot = 'shot.wav';
  static const clear = 'clear.wav';
  static const over = 'over.wav';

  var _ready = false;

  Future<void> prepare() async {
    try {
      await FlameAudio.audioCache.loadAll([shot, clear, over]);
      _ready = true;
    } catch (e) {
      debugPrint('Sound preload failed: $e');
    }
  }

  void play(String name, {double volume = 0.7}) {
    if (!_ready || !profile.soundEnabled) return;
    unawaited(_play(name, volume));
  }

  Future<void> _play(String name, double volume) async {
    try {
      await FlameAudio.play(name, volume: volume);
    } catch (e) {
      debugPrint('Sound failed: $e');
    }
  }
}
