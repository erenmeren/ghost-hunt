import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../game/entities.dart';
import '../game/game_state.dart';
import '../game/maze.dart';
import 'sprites.dart';

const wallBlue = Color(0xFF2121DE);

/// Classic overhead view used by Easy mode.
class TopDownPainter extends CustomPainter {
  TopDownPainter(this.s);

  final GameState s;

  @override
  void paint(Canvas canvas, Size size) {
    final m = s.maze;
    final cell = math.min(size.width / m.width, size.height / m.height);
    final ox = (size.width - cell * m.width) / 2;
    final oy = (size.height - cell * m.height) / 2;
    Offset at(double x, double y) => Offset(ox + x * cell, oy + y * cell);

    final edge = Paint()
      ..color = wallBlue
      ..strokeWidth = math.max(1.5, cell * 0.14)
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = const Color(0xFF0A0A3A);
    final pellet = Paint()..color = pelletColor;
    final blink = (s.clock * 3).floor().isEven || s.phase != Phase.playing;

    for (var y = 0; y < m.height; y++) {
      for (var x = 0; x < m.width; x++) {
        final t = m.at(x, y);
        final r = Rect.fromLTWH(ox + x * cell, oy + y * cell, cell, cell);
        switch (t) {
          case Tile.wall:
            canvas.drawRect(r, fill);
            if (!m.isWallXY(x, y - 1)) {
              canvas.drawLine(r.topLeft, r.topRight, edge);
            }
            if (!m.isWallXY(x, y + 1)) {
              canvas.drawLine(r.bottomLeft, r.bottomRight, edge);
            }
            if (!m.isWallXY(x - 1, y)) {
              canvas.drawLine(r.topLeft, r.bottomLeft, edge);
            }
            if (!m.isWallXY(x + 1, y)) {
              canvas.drawLine(r.topRight, r.bottomRight, edge);
            }
          case Tile.door:
            canvas.drawRect(
              Rect.fromLTWH(r.left, r.center.dy - cell * 0.1, cell, cell * 0.2),
              Paint()..color = const Color(0xFFFFB8DE),
            );
          case Tile.pellet:
            canvas.drawRect(
              Rect.fromCenter(
                center: r.center,
                width: cell * 0.25,
                height: cell * 0.25,
              ),
              pellet,
            );
          case Tile.power:
            if (blink) canvas.drawCircle(r.center, cell * 0.38, pellet);
          default:
            break;
        }
      }
    }

    // Ghosts.
    for (final g in s.ghosts) {
      if (!g.visible) continue;
      final c = at(g.x(m), g.y(m));
      final flashing = s.frightTimer < 2 && (s.clock * 5).floor().isEven;
      if (g.isPlayer) {
        // Mark "you" with a pulsing halo.
        final pulse = 0.5 + 0.5 * math.sin(s.clock * 6);
        canvas.drawCircle(
          c,
          cell * (0.95 + pulse * 0.15),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, cell * 0.1),
        );
      }
      drawGhost(
        canvas,
        c,
        cell * 0.72,
        color: g.color,
        frightened: g.frightened,
        flashing: flashing,
        eyesOnly: g.state == GhostState.eaten,
        lookX: g.dir.dx.toDouble(),
        lookY: g.dir.dy.toDouble(),
        wobble: s.clock * 4,
      );
    }

    // Pac-Man.
    if (s.phase != Phase.caught || (s.clock * 6).floor().isEven) {
      drawPacman(
        canvas,
        at(s.pac.x(m), s.pac.y(m)),
        cell * 0.75,
        s.pac.mouthOpen,
        facing: s.pac.dir.angle,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
