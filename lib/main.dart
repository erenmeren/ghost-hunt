import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'audio/sfx.dart';
import 'game/game_state.dart';
import 'ui/game_screen.dart';
import 'ui/sprites.dart';
import 'ui/top_down_painter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const GhostHuntApp());
}

class GhostHuntApp extends StatefulWidget {
  const GhostHuntApp({super.key});

  @override
  State<GhostHuntApp> createState() => _GhostHuntAppState();
}

class _GhostHuntAppState extends State<GhostHuntApp> {
  final sfx = Sfx();

  @override
  void dispose() {
    sfx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Web debug shortcut: ?mode=easy|hard|hell&level=N starts a game directly.
    final q = kIsWeb ? Uri.base.queryParameters : const <String, String>{};
    final auto = Difficulty.values
        .where((d) => d.name == q['mode'])
        .firstOrNull;
    return MaterialApp(
      title: 'Ghost Hunt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: wallBlue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: auto != null
          ? GameScreen(
              difficulty: auto,
              sfx: sfx,
              level: int.tryParse(q['level'] ?? '') ?? 1,
            )
          : MenuScreen(sfx: sfx),
    );
  }
}

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key, required this.sfx});

  final Sfx sfx;

  Future<void> _start(BuildContext context, Difficulty d) async {
    // Audio may only start after a user gesture on the web.
    await sfx.init();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(difficulty: d, sfx: sfx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 90,
                    child: CustomPaint(
                      size: const Size(220, 90),
                      painter: _TitleArt(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'GHOST HUNT',
                    style: TextStyle(
                      color: pacYellow,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Bu sefer hayalet sensin. Pac-Man yemleri bitirmeden onu yakala.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 28),
                  _ModeButton(
                    title: 'EASY',
                    subtitle: 'Klasik üstten görünüm. Her şey ekranda.',
                    color: const Color(0xFF00E5FF),
                    onTap: () => _start(context, Difficulty.easy),
                  ),
                  _ModeButton(
                    title: 'HARD',
                    subtitle: 'Hayaletin gözünden 3D. Pac-Man\'in ışık huzmesi duvarların üstünden görünür, yedikçe kalp gibi atar. Yaklaştıkça "waka" sesi artar.',
                    color: const Color(0xFFFFB851),
                    onTap: () => _start(context, Difficulty.hard),
                  ),
                  _ModeButton(
                    title: 'HELL',
                    subtitle: '3D, hiçbir ipucu yok. Haritada sadece duvarlar ve sen.',
                    color: const Color(0xFFFF2020),
                    onTap: () => _start(context, Difficulty.hell),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Kontroller — Easy: kaydır / ok tuşları.\n'
                    '3D: sola-sağa kaydır = sonraki kavşakta dön, aşağı = geri dön.\n'
                    'Klavye: ← → dön, ↓ geri, M harita, P duraklat.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
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

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: const Color(0xFF0A0A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
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

class _TitleArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    drawPacman(canvas, Offset(size.width * 0.2, cy), 30, 0.7);
    drawGhost(
      canvas,
      Offset(size.width * 0.62, cy),
      30,
      color: const Color(0xFF00E5FF),
      lookX: -1,
    );
    drawGhost(
      canvas,
      Offset(size.width * 0.9, cy),
      22,
      color: const Color(0xFFFF2020),
      lookX: -1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
