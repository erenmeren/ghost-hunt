import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../audio/sfx.dart';
import '../game/economy.dart';
import '../game/entities.dart';
import '../game/game_state.dart';
import '../game/maze.dart';
import 'minimap_painter.dart';
import 'raycast_painter.dart';
import 'shader_scene.dart';
import 'shop_screen.dart';
import 'sprites.dart';
import 'top_down_painter.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.difficulty,
    required this.sfx,
    this.profile,
    this.level = 1,
    this.seed,
  });

  final Difficulty difficulty;
  final Sfx sfx;
  final Profile? profile;
  final int level;
  final int? seed;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late GameState s;
  late final Ticker _ticker;
  late Camera cam;
  final _focus = FocusNode();
  Duration _last = Duration.zero;
  bool paused = false;
  bool showMap = true;
  String? flash; // short centre message
  double _flashTimer = 0;
  Offset _swipe = Offset.zero;
  bool _swipeUsed = false;

  late final Profile profile = widget.profile ?? Profile();

  @override
  void initState() {
    super.initState();
    _newGame(widget.level);
    _ticker = createTicker(_onTick)..start();
    if (Scene3D.enabled) {
      Scene3D.load().then((sc) {
        if (mounted) setState(() => scene = sc);
      });
    }
  }

  Scene3D? scene;

  /// Hell only: a short hop that lets you peek over the walls for
  /// Pac-Man's glow. Needs the 3D renderer.
  static const jumpTime = 1.1, jumpCooldown = 4.0;
  double _jumpT = 0, _jumpCool = 0;
  bool get _canJump =>
      scene != null &&
      s.difficulty == Difficulty.hell &&
      s.phase == Phase.playing;
  void _jump() {
    if (!_canJump || _jumpT > 0 || _jumpCool > 0) return;
    _jumpT = jumpTime;
    _jumpCool = jumpCooldown;
    widget.sfx.play('turn', volume: 0.6);
  }

  final view3d = View3D();

  void _newGame(int level) {
    s = GameState(
      difficulty: widget.difficulty,
      level: level,
      seed: widget.seed,
      profile: profile,
    );
    final m = s.maze;
    cam = Camera(s.player.x(m), s.player.y(m), s.player.dir.angle);
    flash = null;
    paused = false;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    widget.sfx.stopAll();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    if (paused) return;
    s.update(dt);
    for (final e in s.drainEvents()) {
      _onEvent(e);
    }
    _updateCamera(dt);
    if (_flashTimer > 0) {
      _flashTimer -= dt;
      if (_flashTimer <= 0) flash = null;
    }
    setState(() {});
  }

  void _updateCamera(double dt) {
    final m = s.maze;
    final p = s.player;
    cam.x = p.x(m);
    cam.y = p.y(m);
    var diff = p.dir.angle - cam.angle;
    diff = math.atan2(math.sin(diff), math.cos(diff));
    cam.angle += diff * math.min(1.0, dt * 11);
    final moving = !p.stopped && s.phase == Phase.playing;
    cam.bob = moving ? math.sin(s.clock * 9) * 3 : 0;
    // Jump: an arc that lifts your eyes over the walls, looking down a bit.
    if (_jumpT > 0) _jumpT = math.max(0, _jumpT - dt);
    if (_jumpCool > 0) _jumpCool = math.max(0, _jumpCool - dt);
    final arc = _jumpT > 0 ? math.sin(math.pi * (1 - _jumpT / jumpTime)) : 0.0;
    view3d
      ..eyeHeight = 0.5 + 1.5 * arc
      ..pitch = -0.35 * arc;
  }

  void _say(String text, [double secs = 1.4]) {
    flash = text;
    _flashTimer = secs;
  }

  void _onEvent(GameEvent e) {
    final sfx = widget.sfx;
    switch (e.type) {
      case EventType.pellet:
        if (s.difficulty == Difficulty.easy) {
          sfx.play('waka', volume: 0.3);
        } else if (s.proximitySound) {
          _proximityWaka(e.tile);
        }
      case EventType.power:
        sfx.play('power', volume: 0.6);
        _say('Pac-Man güç hapı yedi! KAÇ!', 2);
      case EventType.ghostEaten:
        sfx.play('eat_ghost', volume: 0.5);
      case EventType.playerEaten:
        sfx.play('eat_ghost', volume: 0.8);
        _say('Yendin! Geri dönüyorsun…', 3);
      case EventType.pacCaught:
        sfx.play('death', volume: 0.7);
        _say(
          e.byPlayer
              ? 'YAKALADIN! 👻  +${e.coins} 🪙'
              : 'Takım arkadaşın yakaladı!  +${e.coins} 🪙',
          1.6,
        );
      case EventType.won:
        sfx.play('win', volume: 0.7);
      case EventType.powerUp:
        sfx.play('power', volume: 0.35);
        _say('${e.powerUp!.emoji} ${e.powerUp!.title}!', 1.2);
      case EventType.powerUpEnd:
        sfx.play('turn', volume: 0.5);
      case EventType.lost:
        sfx.play('lose', volume: 0.7);
    }
  }

  /// Waka gets louder the closer Pac-Man is *through the corridors* and is
  /// panned towards the side it is on.
  void _proximityWaka(int tile) {
    final m = s.maze;
    final dist = m.distancesFrom(s.player.nearTile(m), m.pacWalkable)[tile];
    if (dist < 0) return;
    final hearing = s.hearing;
    final v = math.pow((1 - dist / hearing).clamp(0.0, 1.0), 1.6).toDouble();
    final rel =
        math.atan2(m.yOf(tile) + 0.5 - cam.y, m.xOf(tile) + 0.5 - cam.x) -
        cam.angle;
    widget.sfx.play('waka', volume: v * 0.9, balance: math.sin(rel) * 0.8);
  }

  // ----------------------------------------------------------------- input
  void _turn(Turn t) {
    s.inputTurn(t);
    if (t != Turn.none) widget.sfx.play('turn', volume: 0.4);
  }

  void _back() => s.inputBack();

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.space) {
      _jump();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyM) {
      setState(() => showMap = !showMap);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.keyP) {
      setState(() => paused = !paused);
      return KeyEventResult.handled;
    }
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
    ];
    final slot = digits.indexOf(k);
    if (slot >= 0) {
      final packs = _packButtons;
      if (slot < packs.length) s.usePowerUp(packs[slot]);
      return KeyEventResult.handled;
    }
    final up = k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW;
    final down =
        k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyS;
    final left =
        k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA;
    final right =
        k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD;
    if (!(up || down || left || right)) return KeyEventResult.ignored;
    if (s.firstPerson) {
      if (left) _turn(Turn.left);
      if (right) _turn(Turn.right);
      if (down) _back();
      if (up) _turn(Turn.none);
    } else {
      s.inputDir(
        up
            ? Dir.up
            : down
            ? Dir.down
            : left
            ? Dir.left
            : Dir.right,
      );
    }
    return KeyEventResult.handled;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_swipeUsed) return;
    _swipe += d.delta;
    if (_swipe.distance < 24) return;
    _swipeUsed = true;
    final horizontal = _swipe.dx.abs() > _swipe.dy.abs();
    if (s.firstPerson) {
      if (horizontal) {
        _turn(_swipe.dx < 0 ? Turn.left : Turn.right);
      } else if (_swipe.dy > 0) {
        _back();
      } else {
        _turn(Turn.none);
      }
    } else {
      s.inputDir(
        horizontal
            ? (_swipe.dx < 0 ? Dir.left : Dir.right)
            : (_swipe.dy < 0 ? Dir.up : Dir.down),
      );
    }
  }

  // ------------------------------------------------------------------- UI
  @override
  Widget build(BuildContext context) {
    final fp = s.firstPerson;
    final frightened = s.player.frightened;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) {
            _swipe = Offset.zero;
            _swipeUsed = false;
          },
          onPanUpdate: _onPanUpdate,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: !fp
                      ? TopDownPainter(s)
                      : scene != null
                      ? ShaderScenePainter(scene!, s, cam, view3d)
                      : RaycastPainter(s, cam),
                ),
              ),
              if (fp && frightened)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: frightBlue.withValues(
                        alpha: 0.12 + 0.08 * math.sin(s.clock * 10),
                      ),
                    ),
                  ),
                ),
              if (fp && (s.invisible || s.isActive(PowerUp.phase)))
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: 1.1,
                          colors: [
                            Colors.transparent,
                            (s.isActive(PowerUp.phase)
                                    ? const Color(0xFFB388FF)
                                    : Colors.white)
                                .withValues(alpha: 0.28),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (fp && s.player.state == GhostState.eaten)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(child: _hud()),
              ),
              if (fp) _turnButtons(),
              _powerBar(),
              if (fp) _minimap(),
              _centerMessage(),
              if (paused) _pauseMenu(),
              if (s.phase == Phase.won || s.phase == Phase.lost) _endDialog(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hud() {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.bold,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.pause_circle_outline, color: Colors.white),
            onPressed: () => setState(() => paused = true),
          ),
          Text('Seviye ${s.level}', style: style),
          const SizedBox(width: 14),
          Text('Yem ${s.maze.pelletsLeft}', style: style),
          const SizedBox(width: 14),
          CoinLabel(profile.coins),
          const Spacer(),
          Text('Yakaladığın ${s.playerCatches}  ', style: style),
          for (var i = 0; i < s.pacLives; i++)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: CustomPaint(size: const Size(18, 18), painter: _PacIcon()),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _turnButtons() {
    Widget btn(IconData icon, VoidCallback onTap, bool active) => Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: active
            ? s.player.color.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 62,
            height: 62,
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
    return Positioned(
      left: 10,
      bottom: 16,
      child: SafeArea(
        child: Row(
          children: [
            btn(
              Icons.turn_left,
              () => _turn(Turn.left),
              s.queuedTurn == Turn.left,
            ),
            btn(Icons.u_turn_left, _back, false),
            btn(
              Icons.turn_right,
              () => _turn(Turn.right),
              s.queuedTurn == Turn.right,
            ),
            if (_canJump)
              Opacity(
                opacity: _jumpCool > 0 ? 0.4 : 1,
                child: btn(Icons.keyboard_double_arrow_up, _jump, _jumpT > 0),
              ),
          ],
        ),
      ),
    );
  }

  /// Packs that make sense in this mode (sonar is useless in Easy).
  List<PowerUp> get _packButtons => [
    for (final p in PowerUp.values)
      if (!(p == PowerUp.sonar && !s.firstPerson)) p,
  ];

  bool get _touch {
    final p = Theme.of(context).platform;
    return p == TargetPlatform.iOS || p == TargetPlatform.android;
  }

  Widget _powerBar() {
    final fp = s.firstPerson;
    Widget btn(PowerUp p, int key) {
      final count = profile.packsOf(p);
      final left = s.active[p];
      final usable = s.canUse(p);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Material(
          color: left != null
              ? s.player.color.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: usable ? 0.16 : 0.06),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: usable ? () => s.usePowerUp(p) : null,
            child: SizedBox(
              width: 54,
              height: 54,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: usable || left != null ? 1 : 0.35,
                    child: Text(p.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                  if (left != null)
                    Positioned(
                      bottom: 2,
                      child: Text(
                        left.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Positioned(
                    right: 4,
                    top: 2,
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: pacYellow,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (!_touch)
                    Positioned(
                      left: 5,
                      top: 2,
                      child: Text(
                        '$key',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
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

    final packs = _packButtons;
    return Positioned(
      left: 10,
      top: 0,
      bottom: fp ? 100 : 0,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < packs.length; i++) btn(packs[i], i + 1),
              const SizedBox(height: 2),
              Text(
                'Hak: ${s.packsLeftThisLevel}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _minimap() {
    final short = MediaQuery.sizeOf(context).shortestSide;
    final w = (short * 0.38).clamp(120.0, 220.0);
    final h = w * s.maze.height / s.maze.width;
    return Positioned(
      right: 10,
      bottom: 16,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showMap)
              Container(
                width: w,
                height: h,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CustomPaint(painter: MinimapPainter(s, cam.angle)),
                ),
              ),
            const SizedBox(height: 6),
            TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
              ),
              onPressed: () => setState(() => showMap = !showMap),
              icon: Icon(showMap ? Icons.map : Icons.map_outlined, size: 18),
              label: Text(showMap ? 'Haritayı kapat' : 'Harita'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centerMessage() {
    String? text = flash;
    if (s.phase == Phase.ready) text = 'HAZIR!';
    if (text == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.35),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: pacYellow,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(blurRadius: 8, color: Colors.black)],
          ),
        ),
      ),
    );
  }

  Widget _panel(List<Widget> children) => Positioned.fill(
    child: Container(
      color: Colors.black.withValues(alpha: 0.7),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: wallBlue, width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    ),
  );

  Widget _pauseMenu() => _panel([
    const Text(
      'Durduruldu',
      style: TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    ),
    const SizedBox(height: 20),
    FilledButton(
      onPressed: () => setState(() => paused = false),
      child: const Text('Devam'),
    ),
    const SizedBox(height: 8),
    OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Ana menü'),
    ),
  ]);

  Widget _endDialog() {
    final won = s.phase == Phase.won;
    return _panel([
      Text(
        won ? 'Pac-Man yakalandı!' : 'Pac-Man kaçtı…',
        style: TextStyle(
          color: won ? s.player.color : pacYellow,
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        won
            ? 'Senin yakaladıkların: ${s.playerCatches} / ${s.teamCatches}\nSüre: ${s.time.toStringAsFixed(0)} sn'
            : 'Bütün yemleri bitirdi.\nKalan canı: ${s.pacLives}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 16),
      ),
      const SizedBox(height: 8),
      Text(
        'Bu bölümde kazandığın: ${s.coinsEarned} 🪙   Toplam: ${profile.coins} 🪙',
        textAlign: TextAlign.center,
        style: const TextStyle(color: pacYellow, fontSize: 14),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ShopScreen(profile: profile)),
          );
          if (mounted) setState(() {});
        },
        icon: const Text('🛒'),
        label: const Text('Shop'),
      ),
      const SizedBox(height: 8),
      if (won)
        FilledButton(
          onPressed: () => setState(() => _newGame(s.level + 1)),
          child: Text('Sonraki seviye (${s.level + 1})'),
        ),
      if (!won)
        FilledButton(
          onPressed: () => setState(() => _newGame(s.level)),
          child: const Text('Tekrar dene'),
        ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Ana menü'),
      ),
    ]);
  }
}

class _PacIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => drawPacman(
    canvas,
    size.center(Offset.zero),
    size.width / 2,
    0.6,
    facing: math.pi,
  );

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
