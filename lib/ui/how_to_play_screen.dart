import 'package:material_ui/material_ui.dart';

import '../game/economy.dart';
import '../game/game_state.dart';
import 'sprites.dart';
import 'top_down_painter.dart' show wallBlue;

/// "How to play": goal, modes, packs, coins and controls. Opened from the
/// menu. Pack/upgrade texts and numbers come from the game code itself so
/// this page cannot drift from the shop.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  // Same colours as the mode buttons on the menu.
  static const _easy = Color(0xFF00E5FF);
  static const _hard = Color(0xFFFFB851);
  static const _hell = Color(0xFFFF2020);

  @override
  Widget build(BuildContext context) {
    const e = Difficulty.easy;
    final catchMin = Rewards.playerCatch(e, 0);
    final catchMax = Rewards.playerCatch(e, 1);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'HOW TO PLAY',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Header('Goal'),
                const _Bullet(
                  'This time you\'re the ghost. The runner plays on his own: he '
                  'eats pellets and runs from you. Your job is to catch him '
                  'before he eats them all.',
                ),
                const _Bullet(
                  'The runner starts with 3 lives. Every time you or your '
                  'teammates (the other three ghosts) catch him, he loses one. '
                  'When he runs out, you win and move on to the next level.',
                ),
                const _Bullet(
                  'If the runner eats all the pellets, he wins and you try the '
                  'level again.',
                ),
                const _Bullet(
                  'When the runner eats a power pellet, the ghosts turn blue for '
                  'a while and he chases you all: run! Touch him while you\'re '
                  'blue and you get eaten, then respawn at your starting point '
                  'a few seconds later.',
                ),
                const _Bullet(
                  'Fruit sometimes shows up below the ghost house. Ghosts '
                  'can\'t eat it, only he can, and it makes him faster for a '
                  'moment.',
                ),
                const _Bullet(
                  'The runner gets a little faster and smarter every level.',
                ),
                const SizedBox(height: 18),
                const _Header('Modes'),
                const _ModeCard(
                  title: 'EASY',
                  color: _easy,
                  lines: [
                    'Classic top-down 2D view. Everything is on screen: the '
                        'maze, the pellets, the runner and the other ghosts.',
                    'Swipe or use the arrow keys to choose which way to go.',
                    'The Sonar pack can\'t be used in this mode.',
                  ],
                ),
                _ModeCard(
                  title: 'HARD',
                  color: _hard,
                  lines: [
                    'First-person 3D through the ghost\'s eyes.',
                    'The runner\'s yellow light beam shows above the walls and '
                        'beats like a heart, faster as he eats pellets.',
                    'The "waka" gets louder as the runner nears you through the '
                        'corridors, and you hear it from the side he is on.',
                    'The map at the bottom right doesn\'t show the runner, but it '
                        'does show the pellets left: the trail of eaten '
                        'pellets is your clue.',
                    'Coins earned ×${Rewards.multiplier(Difficulty.hard)}.',
                  ],
                ),
                _ModeCard(
                  title: 'HELL',
                  color: _hell,
                  lines: [
                    '3D, no visual hints: no light beam, only the walls and '
                        'you on the map.',
                    'Trust your ears alone: find the runner by his "waka".',
                    'Jump to peek over the walls for a moment and look for '
                        'the runner\'s glow (once every few seconds).',
                    'Coins earned ×${Rewards.multiplier(Difficulty.hell)}.',
                  ],
                ),
                const SizedBox(height: 18),
                const _Header('Packs'),
                const _Note(
                  'Bought in the shop, used during a level with the buttons on '
                  'the left or keys 1–4, and gone once used. You can use up to '
                  '2 packs per level (more with 🎒 Big bag). You can\'t use a '
                  'pack again while its effect is still active.',
                ),
                for (final p in PowerUp.values)
                  _ItemCard(
                    emoji: p.emoji,
                    title: p.title,
                    description: p == PowerUp.sonar
                        ? '${p.description} Hard and Hell only.'
                        : p.description,
                    extra: '🪙 ${p.price}',
                  ),
                const SizedBox(height: 18),
                const _Header('Coins & upgrades'),
                _Bullet(
                  'Catch the runner yourself to earn $catchMin–$catchMax 🪙; the '
                  'earlier you catch him, the more you get. If a teammate '
                  'catches him you get ${Rewards.teamCatch(e)} 🪙, and winning '
                  'the level pays a bonus.',
                ),
                _Bullet(
                  'Earnings are ×${Rewards.multiplier(Difficulty.hard)} in '
                  'Hard and ×${Rewards.multiplier(Difficulty.hell)} in Hell. '
                  'New players start with ${Profile.welcomeCoins} 🪙.',
                ),
                const _Bullet(
                  'Spend coins in the shop, from the menu or after a level.',
                ),
                const _Note('Permanent upgrades: buy once, keep forever.'),
                for (final u in Upgrade.values)
                  _ItemCard(
                    emoji: u.emoji,
                    title: u.title,
                    description: u.description,
                    extra: 'Up to ${u.maxLevel} levels',
                  ),
                const SizedBox(height: 18),
                const _Header('Controls'),
                const _Control(
                  'Easy',
                  'Swipe, arrow keys or WASD: go that way.',
                ),
                const _Control(
                  'Hard / Hell',
                  'Swipe left/right, ← → (A D) or the turn buttons: turn at '
                      'the next junction.',
                ),
                const _Control(
                  '',
                  'Swipe down, ↓ (S) or the ↶ button: turn back.',
                ),
                const _Control(
                  '',
                  'Swipe up or ↑ (W): cancel the queued turn and go straight '
                      'on.',
                ),
                const _Control(
                  '',
                  'You follow bends automatically; at a T-junction you wait '
                      'until you pick a direction.',
                ),
                const _Control('Jump', 'Space or the ⏫ button (Hell only).'),
                const _Control('Packs', '1–4 or the buttons on the left.'),
                const _Control(
                  'Map',
                  'M or the button at the bottom right (Hard, Hell).',
                ),
                const _Control('Pause', 'P, Esc or the ⏸ button.'),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(
      text,
      style: const TextStyle(
        color: pacYellow,
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white54, fontSize: 13),
    ),
  );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text, {this.color = pacYellow});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('•  ', style: TextStyle(color: color, fontSize: 14)),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ],
    ),
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.color,
    required this.lines,
  });

  final String title;
  final Color color;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 6),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF0A0A2A),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color, width: 2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        for (final l in lines) _Bullet(l, color: color),
      ],
    ),
  );
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.extra,
  });

  final String emoji, title, description, extra;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF0A0A2A),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: wallBlue),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  extra,
                  style: const TextStyle(color: pacYellow, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// One controls row: a short label on the left, what to do on the right.
/// An empty label continues the previous row's group.
class _Control extends StatelessWidget {
  const _Control(this.label, this.text);

  final String label, text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ],
    ),
  );
}
