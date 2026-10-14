// lib/src/ui/overlays.dart
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
            const _HomeGlow(top: -40, left: -30, color: Color(0x55FF6EC7), size: 180),
            const _HomeGlow(top: 140, right: -60, color: Color(0x445FD0FF), size: 210),
            const _HomeGlow(bottom: 20, left: -30, color: Color(0x336DFFB0), size: 170),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  children: [
                    const _BrickLogo(),
                    const SizedBox(height: 16),
                    _Podium(scores: profile.topScores),
                    const SizedBox(height: 12),
                    _EmeraldChip(
                      count: profile.emeralds,
                      onTap: _openEmeralds,
                    ),
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
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: widget.game.startGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF53D769),
                          foregroundColor: const Color(0xFF102016),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('Start'),
                      ),
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
    return AlertDialog(
      backgroundColor: const Color(0xFF152028),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Daily reward',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
      content: const Text(
        'You received 1 Extra time, 1 Slow-down and 1 Panic.',
        style: TextStyle(color: Color(0xFFC5D7E2), height: 1.35),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Nice', style: TextStyle(color: Color(0xFF8BE9FF))),
        ),
      ],
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
                emeralds: game.profile.emeraldsThisRound,
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
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: onMenu,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF8BE9FF), width: 1.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('Menu'),
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

class _Podium extends StatelessWidget {
  final List<int> scores;
  const _Podium({required this.scores});

  @override
  Widget build(BuildContext context) {
    int at(int index) => index < scores.length ? scores[index] : 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _PodiumPlace(place: 2, score: at(1), height: 78, color: const Color(0xFF9BB4C2))),
        const SizedBox(width: 8),
        Expanded(child: _PodiumPlace(place: 1, score: at(0), height: 104, color: const Color(0xFFFFD56A))),
        const SizedBox(width: 8),
        Expanded(child: _PodiumPlace(place: 3, score: at(2), height: 64, color: const Color(0xFFE7A07A))),
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
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800),
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
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800),
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
  const _EmeraldChip({required this.count, this.label = 'EMERALDS', this.onTap});

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
    );
  }
}

class _Gem extends StatelessWidget {
  const _Gem();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785398,
      child: Container(
        width: 12,
        height: 12,
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
                    Text(title, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(detail, style: const TextStyle(color: Color(0xFFC5D7E2), fontSize: 12)),
                  ],
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
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
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
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

  @override
  Widget build(BuildContext context) {
    final cost = PlayerProfile.emeraldCost(widget.kind);
    final canBuy = widget.game.profile.emeralds >= cost;
    return AlertDialog(
      backgroundColor: const Color(0xFF152028),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(_title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'You have ${widget.game.profile.countOf(widget.kind)}',
            style: const TextStyle(color: Color(0xFFC5D7E2)),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: !canBuy || _busy
                ? null
                : () {
                    if (widget.game.profile.buyWithEmeralds(widget.kind)) {
                      Navigator.of(context).pop();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF2D3A),
              foregroundColor: Colors.white,
            ),
            child: Text('Buy for $cost emeralds'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
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
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8BE9FF)),
          ),
          if (_note != null) ...[
            const SizedBox(height: 8),
            Text(_note!, style: const TextStyle(color: Color(0xFFFFB4BA), fontSize: 12)),
          ],
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
    return AlertDialog(
      backgroundColor: const Color(0xFF152028),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Emeralds', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'You have ${game.profile.emeralds}',
            style: const TextStyle(color: Color(0xFFFF8A93), fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (final pack in EmeraldShop.packs) ...[
            OutlinedButton(
              onPressed: shop == null
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
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF8A93)),
              child: Text(
                '${pack.title} · ${pack.emeralds}  ·  ${shop?.priceLabel(pack) ?? 'Store'}',
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_note != null)
            Text(_note!, style: const TextStyle(color: Color(0xFFC5D7E2), fontSize: 12)),
        ],
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
