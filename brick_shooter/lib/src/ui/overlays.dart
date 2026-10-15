// lib/src/ui/overlays.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../game/my_game.dart';
import '../game/player_profile.dart';
import '../purchases/emerald_shop.dart';

class MenuOverlay extends StatefulWidget {
  static const id = 'menu';
  final MyGame game;
  const MenuOverlay({super.key, required this.game});

  @override
  State<MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<MenuOverlay> {
  var _showingDaily = false;

  @override
  void initState() {
    super.initState();
    widget.game.profile.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDaily());
  }

  @override
  void dispose() {
    widget.game.profile.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
    _maybeShowDaily();
  }

  void _maybeShowDaily() {
    final profile = widget.game.profile;
    if (!profile.pendingDailyNotice || _showingDaily || !mounted) return;
    _showingDaily = true;
    profile.pendingDailyNotice = false;
    final dialogContext = context;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!dialogContext.mounted) {
        _showingDaily = false;
        return;
      }
      await showDialog<void>(
        context: dialogContext,
        builder: (context) => const _DailyRewardDialog(),
      );
      _showingDaily = false;
    });
  }

  Future<void> _openPower(PowerUp kind) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _PowerOfferDialog(game: widget.game, kind: kind),
    );
  }

  Future<void> _openEmeralds() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _EmeraldShopDialog(game: widget.game),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.game.profile;
    return Material(
      color: const Color(0xFF071018),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF102433), Color(0xFF071018), Color(0xFF140E22)],
          ),
        ),
        child: Stack(
          children: [
            const _HomeGlow(
              top: -40,
              left: -30,
              color: Color(0x55FF6EC7),
              size: 180,
            ),
            const _HomeGlow(
              top: 140,
              right: -60,
              color: Color(0x445FD0FF),
              size: 210,
            ),
            const _HomeGlow(
              bottom: 20,
              left: -30,
              color: Color(0x336DFFB0),
              size: 170,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  children: [
                    const _BrickLogo(),
                    const SizedBox(height: 16),
                    _Podium(scores: profile.topScores),
                    const SizedBox(height: 12),
                    _EmeraldChip(count: profile.emeralds, onTap: _openEmeralds),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView(
                        children: [
                          _PowerCard(
                            title: 'Extra time',
                            detail: '+15 seconds',
                            count: profile.extraTime,
                            color: const Color(0xFF5FD0FF),
                            icon: Icons.add,
                            onTap: () => _openPower(PowerUp.extraTime),
                          ),
                          const SizedBox(height: 10),
                          _PowerCard(
                            title: 'Slow-down',
                            detail: 'Slower rows for 5 seconds',
                            count: profile.slowDown,
                            color: const Color(0xFFB388FF),
                            icon: Icons.speed,
                            onTap: () => _openPower(PowerUp.slowDown),
                          ),
                          const SizedBox(height: 10),
                          _PowerCard(
                            title: 'Panic',
                            detail: 'Clears every visible row',
                            count: profile.panic,
                            color: const Color(0xFFFF6EC7),
                            icon: Icons.bolt,
                            onTap: () => _openPower(PowerUp.panic),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PulseCta(
                      key: const Key('menu-start'),
                      label: 'Start',
                      onPressed: widget.game.startGame,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyRewardDialog extends StatelessWidget {
  const _DailyRewardDialog();

  @override
  Widget build(BuildContext context) {
    return _ArcadeDialog(
      accent: const Color(0xFFFFD56A),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BobbingBricks(),
          const SizedBox(height: 14),
          const _Pill(label: 'TODAY', color: Color(0xFFFFD56A)),
          const SizedBox(height: 10),
          const Text(
            'Daily reward',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'A fresh set just dropped into your stash.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFC5D7E2), height: 1.35),
          ),
          const SizedBox(height: 16),
          const _RewardLine(
            color: Color(0xFF5FD0FF),
            icon: Icons.add,
            title: 'Extra time',
            detail: '+15 seconds',
          ),
          const _RewardLine(
            color: Color(0xFFB388FF),
            icon: Icons.speed,
            title: 'Slow-down',
            detail: 'Slower rows for 5 seconds',
          ),
          const _RewardLine(
            color: Color(0xFFFF6EC7),
            icon: Icons.bolt,
            title: 'Panic',
            detail: 'Clears every visible row',
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF53D769),
                foregroundColor: const Color(0xFF102016),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Nice!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
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
    final curved = CurvedAnimation(
      parent: _entrance,
      curve: Curves.easeOutCubic,
    );
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
          const ModalBarrier(color: Color(0xC0101820), dismissible: false),
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
                  emeralds: game.profile.emeraldsThisRound,
                  onPlayAgain: game.startGame,
                  onMenu: game.backToMenu,
                ),
              ),
            ),
          ),
          if (game.score.newBest)
            const Positioned.fill(
              child: IgnorePointer(
                child: _HighScoreConfetti(key: Key('highscore-confetti')),
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
  final int emeralds;
  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;

  const _GameOverCard({
    required this.score,
    required this.best,
    required this.isNewBest,
    required this.multiplier,
    required this.emeralds,
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
                const SizedBox(height: 16),
                _EmeraldChip(count: emeralds, label: 'EMERALDS THIS ROUND'),
                const SizedBox(height: 16),
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
                const SizedBox(height: 26),
                _PulseCta(
                  key: const Key('gameover-play'),
                  label: 'Play again',
                  fontSize: 18,
                  onPressed: onPlayAgain,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: onMenu,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xFF8BE9FF),
                        width: 1.6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Menu',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
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
        _MiniBrick(color: Color(0xFFFF6EC7)),
        SizedBox(width: 6),
        _MiniBrick(color: Color(0xFF5FD0FF)),
        SizedBox(width: 6),
        _MiniBrick(color: Color(0xFFB388FF)),
        SizedBox(width: 6),
        _MiniBrick(color: Color(0xFF6DFFB0)),
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

class _NewBestChip extends StatelessWidget {
  const _NewBestChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x33FFD56A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFD56A)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: Color(0xFFFFD56A), size: 14),
          SizedBox(width: 6),
          Text(
            'NEW BEST',
            style: TextStyle(
              color: Color(0xFFFFD56A),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ],
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

class _Podium extends StatelessWidget {
  final List<int> scores;
  const _Podium({required this.scores});

  @override
  Widget build(BuildContext context) {
    int at(int index) => index < scores.length ? scores[index] : 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _PodiumPlace(
            place: 2,
            score: at(1),
            height: 78,
            color: const Color(0xFF9BB4C2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PodiumPlace(
            place: 1,
            score: at(0),
            height: 104,
            color: const Color(0xFFFFD56A),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PodiumPlace(
            place: 3,
            score: at(2),
            height: 64,
            color: const Color(0xFFE7A07A),
          ),
        ),
      ],
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  final int place;
  final int score;
  final double height;
  final Color color;

  const _PodiumPlace({
    required this.place,
    required this.score,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          score > 0 ? _formatScore(score) : '—',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: height,
          alignment: Alignment.topCenter,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: color.withValues(alpha: 0.7)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '$place',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmeraldChip extends StatelessWidget {
  final int count;
  final String label;
  final VoidCallback? onTap;
  const _EmeraldChip({
    required this.count,
    this.label = 'EMERALDS',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x33FF2D3A),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFFF2D3A)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Gem(),
                const SizedBox(width: 8),
                Text(
                  '$count',
                  style: const TextStyle(
                    color: Color(0xFFFF8A93),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFFFB4BA),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Gem extends StatelessWidget {
  final double size;
  const _Gem({this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785398,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFFF2D3A),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: const Color(0xFFFFB4BA)),
        ),
      ),
    );
  }
}

class _PowerCard extends StatelessWidget {
  final String title;
  final String detail;
  final int count;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _PowerCard({
    required this.title,
    required this.detail,
    required this.count,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE616242E),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.85)),
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.22), const Color(0x00101820)],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.25),
                  border: Border.all(color: color),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: Color(0xFFC5D7E2),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeGlow extends StatelessWidget {
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final Color color;
  final double size;

  const _HomeGlow({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

class _BrickLogo extends StatelessWidget {
  const _BrickLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MiniBrick(color: Color(0xFFFF6EC7)),
            SizedBox(width: 5),
            _MiniBrick(color: Color(0xFF5FD0FF)),
            SizedBox(width: 5),
            _MiniBrick(color: Color(0xFFB388FF)),
            SizedBox(width: 5),
            _MiniBrick(color: Color(0xFF6DFFB0)),
          ],
        ),
        const SizedBox(height: 8),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF6EC7), Color(0xFF5FD0FF), Color(0xFF6DFFB0)],
          ).createShader(bounds),
          child: const Text(
            'BRICK SHOOTER',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _PowerOfferDialog extends StatefulWidget {
  final MyGame game;
  final PowerUp kind;
  const _PowerOfferDialog({required this.game, required this.kind});

  @override
  State<_PowerOfferDialog> createState() => _PowerOfferDialogState();
}

class _PowerOfferDialogState extends State<_PowerOfferDialog> {
  bool _busy = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    widget.game.profile.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.game.profile.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String get _title {
    switch (widget.kind) {
      case PowerUp.extraTime:
        return 'Extra time';
      case PowerUp.slowDown:
        return 'Slow-down';
      case PowerUp.panic:
        return 'Panic';
    }
  }

  String get _detail {
    switch (widget.kind) {
      case PowerUp.extraTime:
        return '+15 seconds on the clock';
      case PowerUp.slowDown:
        return 'Slower rows for 5 seconds';
      case PowerUp.panic:
        return 'Clears every visible row';
    }
  }

  Color get _color {
    switch (widget.kind) {
      case PowerUp.extraTime:
        return const Color(0xFF5FD0FF);
      case PowerUp.slowDown:
        return const Color(0xFFB388FF);
      case PowerUp.panic:
        return const Color(0xFFFF6EC7);
    }
  }

  IconData get _icon {
    switch (widget.kind) {
      case PowerUp.extraTime:
        return Icons.add;
      case PowerUp.slowDown:
        return Icons.speed;
      case PowerUp.panic:
        return Icons.bolt;
    }
  }

  Future<void> _openEmeralds() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _EmeraldShopDialog(game: widget.game),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cost = PlayerProfile.emeraldCost(widget.kind);
    final owned = widget.game.profile.countOf(widget.kind);
    final emeralds = widget.game.profile.emeralds;
    final canBuy = emeralds >= cost;
    return _ArcadeDialog(
      accent: _color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _color.withValues(alpha: 0.2),
              border: Border.all(color: _color, width: 2),
            ),
            child: Icon(_icon, color: _color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            _title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFC5D7E2), height: 1.3),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoPill(label: 'OWNED', value: '$owned'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoPill(
                  label: 'COST',
                  value: '$cost',
                  valueColor: const Color(0xFFFF8A93),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You have $emeralds emeralds',
            style: const TextStyle(
              color: Color(0xFFFFB4BA),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    key: const Key('power-buy'),
                    // A disabled Material button fades toward black and
                    // disappears on this dark card. Keep the label readable.
                    onPressed: !canBuy || _busy
                        ? null
                        : () {
                            if (widget.game.profile.buyWithEmeralds(
                              widget.kind,
                            )) {
                              Navigator.of(context).pop();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2D3A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFB42332),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Buy for $cost emeralds',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!canBuy) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Tooltip(
                    message: 'Emeralds',
                    child: ElevatedButton(
                      key: const Key('power-emerald-cart'),
                      onPressed: _openEmeralds,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B2836),
                        foregroundColor: const Color(0xFFFF8A93),
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(
                            color: Color(0xFFFF2D3A),
                            width: 1.4,
                          ),
                        ),
                      ),
                      child: const Icon(
                        Icons.shopping_cart,
                        semanticLabel: 'Open emeralds',
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _note = null;
                      });
                      final earned = await widget.game.rewardedAds.show();
                      if (!context.mounted) return;
                      if (earned) {
                        widget.game.profile.grant(widget.kind);
                        Navigator.of(context).pop();
                      } else {
                        setState(() {
                          _busy = false;
                          _note = 'Ad not ready. Try again.';
                        });
                      }
                    },
              icon: const Icon(Icons.smart_display_outlined),
              label: Text(_busy ? 'Loading ad…' : 'Watch ad'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8BE9FF),
                disabledForegroundColor: const Color(0xFF8BE9FF),
                side: const BorderSide(color: Color(0xFF8BE9FF), width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (_note != null) ...[
            const SizedBox(height: 8),
            Text(
              _note!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFB4BA), fontSize: 12),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Color(0xFF9BB4C2),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmeraldShopDialog extends StatefulWidget {
  final MyGame game;
  const _EmeraldShopDialog({required this.game});

  @override
  State<_EmeraldShopDialog> createState() => _EmeraldShopDialogState();
}

class _EmeraldShopDialogState extends State<_EmeraldShopDialog> {
  String? _note;

  @override
  void initState() {
    super.initState();
    widget.game.profile.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.game.profile.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final shop = game.shop;
    return _ArcadeDialog(
      accent: const Color(0xFFFF2D3A),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Gem(size: 22),
          const SizedBox(height: 10),
          const Text(
            'Emeralds',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You have ${game.profile.emeralds}',
            style: const TextStyle(
              color: Color(0xFFFF8A93),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Stock up, then spend them on power-ups.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFC5D7E2),
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          for (final pack in EmeraldShop.packs) ...[
            _EmeraldPackTile(
              pack: pack,
              price: shop?.priceLabel(pack) ?? 'Store',
              onTap: shop == null
                  ? null
                  : () async {
                      final started = await shop.buy(pack);
                      if (!mounted) return;
                      setState(() {
                        _note = started
                            ? 'Opening the store…'
                            : 'That pack is not in the store yet.';
                      });
                    },
            ),
            const SizedBox(height: 8),
          ],
          if (_note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _note!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFC5D7E2), fontSize: 12),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Color(0xFF9BB4C2),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseCta extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final double fontSize;

  const _PulseCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.fontSize = 20,
  });

  @override
  State<_PulseCta> createState() => _PulseCtaState();
}

class _PulseCtaState extends State<_PulseCta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
    final scale = Tween<double>(begin: 1, end: 1.04).animate(curved);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final glow = 0.18 + (0.32 * curved.value);
        return Transform.scale(
          scale: scale.value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF53D769).withValues(alpha: glow),
                  blurRadius: 16 + (8 * curved.value),
                  spreadRadius: 0.4,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF53D769),
            foregroundColor: const Color(0xFF102016),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcadeDialog extends StatelessWidget {
  final Color accent;
  final Widget child;

  const _ArcadeDialog({required this.accent, required this.child});

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: _PopIn(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 380, maxHeight: maxHeight),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF243848), Color(0xFF121C28)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: accent.withValues(alpha: 0.9),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  Positioned(
                    top: -36,
                    right: -24,
                    child: _GlowDot(
                      color: accent.withValues(alpha: 0.34),
                      size: 120,
                    ),
                  ),
                  const Positioned(
                    bottom: -48,
                    left: -28,
                    child: _GlowDot(color: Color(0x332A6E96), size: 140),
                  ),
                  ListView(
                    shrinkWrap: true,
                    primary: false,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                    children: [child],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PopIn extends StatefulWidget {
  final Widget child;
  const _PopIn({required this.child});

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();
  late final Animation<double> _scale = Tween<double>(
    begin: 0.86,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.55, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

class _GlowDot extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowDot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _BobbingBricks extends StatefulWidget {
  const _BobbingBricks();

  @override
  State<_BobbingBricks> createState() => _BobbingBricksState();
}

class _BobbingBricksState extends State<_BobbingBricks>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) {
        final dy = math.sin(_bob.value * math.pi) * -5;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: const _BrickRow(),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _RewardLine extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String detail;

  const _RewardLine({
    required this.color,
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.85)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: Color(0xFFC5D7E2),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                '+1',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _InfoPill({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x33101820),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x332E6F9A)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9BB4C2),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmeraldPackTile extends StatelessWidget {
  final EmeraldPack pack;
  final String price;
  final VoidCallback? onTap;

  const _EmeraldPackTile({
    required this.pack,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A2834),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xB3FF2D3A)),
          ),
          child: Row(
            children: [
              const _Gem(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _packFlavor(pack.title),
                      style: const TextStyle(
                        color: Color(0xFF9BB4C2),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${pack.emeralds} emeralds',
                      style: const TextStyle(
                        color: Color(0xFFFF8A93),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2D3A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      price,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Speck {
  const _Speck({
    required this.originX,
    required this.originY,
    required this.vx,
    required this.vy,
    required this.gravity,
    required this.spin,
    required this.width,
    required this.height,
    required this.delay,
    required this.color,
    required this.sway,
    required this.shape,
  });

  final double originX;
  final double originY;
  final double vx;
  final double vy;
  final double gravity;
  final double spin;
  final double width;
  final double height;
  final double delay;
  final Color color;
  final double sway;
  final int shape;
}

class _HighScoreConfetti extends StatefulWidget {
  const _HighScoreConfetti({super.key});

  @override
  State<_HighScoreConfetti> createState() => _HighScoreConfettiState();
}

class _HighScoreConfettiState extends State<_HighScoreConfetti>
    with SingleTickerProviderStateMixin {
  static const _colors = <Color>[
    Color(0xFFFF6EC7),
    Color(0xFF5FD0FF),
    Color(0xFFB388FF),
    Color(0xFF6DFFB0),
    Color(0xFFFFD56A),
    Color(0xFFFF8A93),
    Color(0xFFFFFFFF),
  ];

  late final AnimationController _clock;
  late final List<_Speck> _specks;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..forward();
    final random = math.Random(42);
    _specks = List<_Speck>.generate(52, (index) {
      final angle = -math.pi / 2 + (random.nextDouble() - 0.5) * math.pi * 0.9;
      final speed = 140 + random.nextDouble() * 260;
      return _Speck(
        originX: 0.42 + random.nextDouble() * 0.16,
        originY: 0.28 + random.nextDouble() * 0.08,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        gravity: 680 + random.nextDouble() * 160,
        spin: (random.nextDouble() - 0.5) * 14,
        width: 6 + random.nextDouble() * 7,
        height: 8 + random.nextDouble() * 7,
        delay: index < 36
            ? random.nextDouble() * 0.12
            : 0.2 + random.nextDouble() * 0.35,
        color: _colors[index % _colors.length],
        sway: 8 + random.nextDouble() * 16,
        shape: index.isEven ? 0 : 1,
      );
    });
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        return CustomPaint(
          painter: _ConfettiPainter(
            specks: _specks,
            seconds: _clock.value * 5.2,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.specks, required this.seconds});

  final List<_Speck> specks;
  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    for (final speck in specks) {
      final age = seconds - speck.delay;
      if (age <= 0) continue;
      final raw = age < 3.4 ? 1.0 : 1 - ((age - 3.4) / 1.5);
      final fade = raw.clamp(0.0, 1.0).toDouble();
      if (fade <= 0) continue;
      final x =
          speck.originX * size.width +
          speck.vx * age +
          math.sin(age * 4.2 + speck.originX * 12) * speck.sway;
      final y =
          speck.originY * size.height +
          speck.vy * age +
          0.5 * speck.gravity * age * age;
      if (y > size.height + 30 || x < -40 || x > size.width + 40) continue;
      final paint = Paint()..color = speck.color.withValues(alpha: 0.92 * fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(speck.spin * age);
      if (speck.shape == 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: speck.width,
              height: speck.height,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      } else {
        final path = Path()
          ..moveTo(0, -speck.height / 2)
          ..lineTo(speck.width / 2, 0)
          ..lineTo(0, speck.height / 2)
          ..lineTo(-speck.width / 2, 0)
          ..close();
        canvas.drawPath(path, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.seconds != seconds;
  }
}

String _packFlavor(String title) {
  switch (title) {
    case 'Pouch':
      return 'A little extra';
    case 'Chest':
      return 'The fun size';
    case 'Vault':
      return 'Go big';
    default:
      return 'Emeralds';
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
