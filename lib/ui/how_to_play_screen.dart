import 'package:material_ui/material_ui.dart';

import '../game/economy.dart';
import '../game/game_state.dart';
import 'sprites.dart';
import 'top_down_painter.dart' show wallBlue;

/// "Nasıl oynanır": goal, modes, packs, coins and controls. Opened from the
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
          tooltip: 'Geri',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'NASIL OYNANIR',
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
                const _Header('Amaç'),
                const _Bullet(
                  'Bu sefer hayalet sensin. Pac-Man kendi kendine oynuyor: '
                  'yemleri yiyor ve senden kaçıyor. Görevin, o bütün yemleri '
                  'bitirmeden onu yakalamak.',
                ),
                const _Bullet(
                  'Pac-Man 3 canla başlar. Sen ya da takım arkadaşların '
                  '(diğer üç hayalet) onu her yakaladığınızda bir canı gider. '
                  'Canları biterse bölümü kazanır, sonraki seviyeye geçersin.',
                ),
                const _Bullet(
                  'Pac-Man bütün yemleri bitirirse o kazanır; bölümü tekrar '
                  'denersin.',
                ),
                const _Bullet(
                  'Pac-Man güç hapı yerse hayaletler bir süre maviye döner ve '
                  'Pac-Man sizi kovalar: kaç! Mavi haldeyken ona değersen '
                  'yenirsin ve birkaç saniye sonra başlangıç noktasında '
                  'yeniden doğarsın.',
                ),
                const _Bullet(
                  'Her seviyede Pac-Man biraz daha hızlı ve daha zeki olur.',
                ),
                const SizedBox(height: 18),
                const _Header('Modlar'),
                const _ModeCard(
                  title: 'EASY',
                  color: _easy,
                  lines: [
                    'Klasik üstten 2D görünüm. Her şey ekranda: labirent, '
                        'yemler, Pac-Man ve diğer hayaletler.',
                    'Kaydırarak ya da ok tuşlarıyla gitmek istediğin yönü '
                        'seçersin.',
                    'Sonar paketi bu modda kullanılmaz.',
                  ],
                ),
                _ModeCard(
                  title: 'HARD',
                  color: _hard,
                  lines: [
                    'Hayaletin gözünden, birinci şahıs 3D.',
                    'Pac-Man\'in sarı ışık huzmesi duvarların üstünden '
                        'görünür; yem yedikçe kalp gibi hızlanarak atar.',
                    '"Waka" sesi Pac-Man koridorlardan sana yaklaştıkça '
                        'yükselir ve geldiği taraftan duyulur.',
                    'Sağ alttaki haritada Pac-Man yok, ama kalan yemler var: '
                        'yenmiş yemlerin bıraktığı iz ipucudur.',
                    'Kazandığın para ×${Rewards.multiplier(Difficulty.hard)}.',
                  ],
                ),
                _ModeCard(
                  title: 'HELL',
                  color: _hell,
                  lines: [
                    '3D, görsel ipucu yok: ışık huzmesi yok, haritada sadece '
                        'duvarlar ve sen.',
                    'Sadece kulağına güven: Pac-Man\'i "waka" sesinden '
                        'bulursun.',
                    'Zıplayıp bir anlığına duvarların üstünden bakabilir, '
                        'Pac-Man\'in parıltısını arayabilirsin (birkaç saniyede '
                        'bir).',
                    'Kazandığın para ×${Rewards.multiplier(Difficulty.hell)}.',
                  ],
                ),
                const SizedBox(height: 18),
                const _Header('Paketler'),
                const _Note(
                  'Shop\'tan alınır, bölüm içinde soldaki düğmelerle ya da '
                  '1–4 tuşlarıyla kullanılır ve kullanınca biter. Bir bölümde '
                  'en fazla 2 paket kullanabilirsin (🎒 Büyük çanta ile daha '
                  'fazla). Etkisi süren bir paketi bitmeden tekrar açamazsın.',
                ),
                for (final p in PowerUp.values)
                  _ItemCard(
                    emoji: p.emoji,
                    title: p.title,
                    description: p == PowerUp.sonar
                        ? '${p.description} Sadece Hard ve Hell\'de.'
                        : p.description,
                    extra: '🪙 ${p.price}',
                  ),
                const SizedBox(height: 18),
                const _Header('Para ve yükseltmeler'),
                _Bullet(
                  'Pac-Man\'i sen yakalarsan $catchMin–$catchMax 🪙 '
                  'kazanırsın; ne kadar erken yakalarsan o kadar çok. Takım '
                  'arkadaşın yakalarsa ${Rewards.teamCatch(e)} 🪙, bölümü '
                  'kazanınca da bonus var.',
                ),
                _Bullet(
                  'Hard\'da kazanç ×${Rewards.multiplier(Difficulty.hard)}, '
                  'Hell\'de ×${Rewards.multiplier(Difficulty.hell)}. Yeni '
                  'oyuncu ${Profile.welcomeCoins} 🪙 ile başlar.',
                ),
                const _Bullet(
                  'Paraları menüdeki shop\'ta ya da bölüm sonunda harcarsın.',
                ),
                const _Note(
                  'Kalıcı yükseltmeler bir kere alınır, hep geçerlidir:',
                ),
                for (final u in Upgrade.values)
                  _ItemCard(
                    emoji: u.emoji,
                    title: u.title,
                    description: u.description,
                    extra: 'En fazla ${u.maxLevel} seviye',
                  ),
                const SizedBox(height: 18),
                const _Header('Kontroller'),
                const _Control(
                  'Easy',
                  'Kaydır, ok tuşları ya da WASD: o yöne git.',
                ),
                const _Control(
                  'Hard / Hell',
                  'Sola-sağa kaydır, ← → (A D) ya da dönüş düğmeleri: bir '
                      'sonraki kavşakta dön.',
                ),
                const _Control(
                  '',
                  'Aşağı kaydır, ↓ (S) ya da ↶ düğmesi: geri dön.',
                ),
                const _Control(
                  '',
                  'Yukarı kaydır ya da ↑ (W): sıradaki dönüşü iptal et, düz '
                      'devam et.',
                ),
                const _Control(
                  '',
                  'Virajlarda kendiliğinden dönersin; T kavşakta sen yön '
                      'seçene kadar beklersin.',
                ),
                const _Control(
                  'Zıplama',
                  'Boşluk ya da ⏫ düğmesi (sadece Hell).',
                ),
                const _Control('Paketler', '1–4 ya da soldaki düğmeler.'),
                const _Control(
                  'Harita',
                  'M ya da sağ alttaki düğme (Hard, Hell).',
                ),
                const _Control('Duraklat', 'P, Esc ya da ⏸ düğmesi.'),
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
