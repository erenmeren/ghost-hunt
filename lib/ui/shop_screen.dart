import 'package:material_ui/material_ui.dart';

import '../game/economy.dart';
import 'sprites.dart';
import 'top_down_painter.dart' show wallBlue;

/// Shop: spend coins on packs (used up in a level) and permanent upgrades.
/// Opened from the menu and between levels.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  Profile get p => widget.profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'SHOP',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: CoinLabel(p.coins, size: 20)),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(
                'Packs',
                'Used during a level, gone once used. '
                    'You can use up to ${p.slotsPerLevel} packs per level.',
              ),
              for (final u in PowerUp.values)
                _ItemTile(
                  emoji: u.emoji,
                  title: u.title,
                  description: u.description,
                  owned: 'Owned: ${p.packsOf(u)}',
                  price: u.price,
                  enabled: p.canBuyPack(u),
                  onBuy: () => setState(() => p.buyPack(u)),
                ),
              const SizedBox(height: 18),
              _header('Permanent upgrades', 'Buy once, keep forever.'),
              for (final u in Upgrade.values)
                _ItemTile(
                  emoji: u.emoji,
                  title: u.title,
                  description: u.description,
                  owned: 'Level ${p.levelOf(u)}/${u.maxLevel}',
                  price: p.upgradePrice(u),
                  enabled:
                      p.upgradePrice(u) != null &&
                      p.coins >= p.upgradePrice(u)!,
                  onBuy: () => setState(() => p.buyUpgrade(u)),
                ),
              const SizedBox(height: 18),
              const Text(
                'Catch Pac-Man to earn coins. The earlier you catch him, '
                'the more you get. Hard ×2, Hell ×4.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(String title, String sub) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: pacYellow,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(sub, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    ),
  );
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.emoji,
    required this.title,
    required this.description,
    required this.owned,
    required this.price,
    required this.enabled,
    required this.onBuy,
  });

  final String emoji, title, description, owned;
  final int? price; // null = maxed out
  final bool enabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0A0A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: wallBlue),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
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
                    owned,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: enabled ? onBuy : null,
              child: price == null ? const Text('MAX') : CoinLabel(price!),
            ),
          ],
        ),
      ),
    );
  }
}

/// "🪙 120" in pac-yellow.
class CoinLabel extends StatelessWidget {
  const CoinLabel(this.amount, {super.key, this.size = 15});

  final int amount;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    '🪙 $amount',
    style: TextStyle(
      color: pacYellow,
      fontSize: size,
      fontWeight: FontWeight.w900,
    ),
  );
}
