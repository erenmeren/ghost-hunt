import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'audio/sfx.dart';
import 'game/economy.dart';
import 'game/game_state.dart';
import 'profile_store.dart';
import 'ui/arcade_layout.dart';
import 'ui/game_screen.dart';
import 'ui/how_to_play_screen.dart';
import 'ui/shop_screen.dart';
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
  Profile? profile;

  @override
  void initState() {
    super.initState();
    ProfileStore.load().then((p) {
      if (mounted) setState(() => profile = p);
    });
  }

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
      home: profile == null
          ? const Scaffold(backgroundColor: Colors.black)
          : auto != null
          ? GameScreen(
              difficulty: auto,
              sfx: sfx,
              profile: profile,
              level: int.tryParse(q['level'] ?? '') ?? 1,
            )
          : MenuScreen(sfx: sfx, profile: profile!),
    );
  }
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.sfx, required this.profile});

  final Sfx sfx;
  final Profile profile;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  Sfx get sfx => widget.sfx;

  static final _menuButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: pacYellow,
    side: const BorderSide(color: pacYellow),
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
  );
  static const _menuButtonText = TextStyle(
    fontWeight: FontWeight.w900,
    fontSize: 16,
  );

  Future<void> _start(BuildContext context, Difficulty d) async {
    // Audio may only start after a user gesture on the web.
    await sfx.init();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            GameScreen(difficulty: d, sfx: sfx, profile: widget.profile),
      ),
    );
    if (mounted) setState(() {}); // coins may have changed
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'GHOST HUNT',
                      style: pixelText(34, color: pacYellow).copyWith(
                        shadows: const [
                          Shadow(color: Color(0x99FFE000), blurRadius: 12),
                          Shadow(color: Color(0x44FFE000), blurRadius: 28),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'This time you\'re the ghost. Catch Pac-Man before he eats all the pellets.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 28),
                  _ModeButton(
                    title: 'EASY',
                    subtitle: 'Classic top-down view. Everything is on screen.',
                    color: const Color(0xFF00E5FF),
                    onTap: () => _start(context, Difficulty.easy),
                  ),
                  _ModeButton(
                    title: 'HARD',
                    subtitle: '3D through the ghost\'s eyes. Pac-Man\'s light beam shows above the walls and beats like a heart as he eats. The "waka" gets louder as you close in.',
                    color: const Color(0xFFFFB851),
                    onTap: () => _start(context, Difficulty.hard),
                  ),
                  _ModeButton(
                    title: 'HELL',
                    subtitle: '3D, no visual hints: no light, only the walls and you on the map. Trust your ears alone.',
                    color: const Color(0xFFFF2020),
                    onTap: () => _start(context, Difficulty.hell),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        style: _menuButtonStyle,
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ShopScreen(profile: widget.profile),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                        icon: const Text('🛒', style: TextStyle(fontSize: 18)),
                        label: Text(
                          'SHOP   🪙 ${widget.profile.coins}',
                          style: _menuButtonText,
                        ),
                      ),
                      OutlinedButton.icon(
                        style: _menuButtonStyle,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HowToPlayScreen(),
                          ),
                        ),
                        icon: const Text('📖', style: TextStyle(fontSize: 18)),
                        label: const Text(
                          'HOW TO PLAY',
                          style: _menuButtonText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Controls — Easy: swipe / arrow keys.\n'
                    '3D: swipe left/right = turn at the next junction, down = turn back.\n'
                    'Keyboard: ← → turn, ↓ back, Space jump (Hell), 1-4 packs, M map, P pause.',
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
