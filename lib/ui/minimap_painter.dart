import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../game/entities.dart';
import '../game/game_state.dart';
import '../game/maze.dart';
import 'sprites.dart';

/// Bottom-right map for the first-person modes. Never shows Pac-Man:
/// in Hard the eaten-pellet trail is the clue, in Hell only the walls and
/// yourself are drawn.
class MinimapPainter extends CustomPainter {
  MinimapPainter(this.s, this.camAngle);

  final GameState s;
  final double camAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final m = s.maze;
    final cell = math.min(size.width / m.width, size.height / m.height);
    final wall = Paint()..color = const Color(0xCC2828C8);
    final door = Paint()..color = const Color(0xFFFFB8DE);
    final pellet = Paint()..color = pelletColor.withValues(alpha: 0.8);
    for (var y = 0; y < m.height; y++) {
      for (var x = 0; x < m.width; x++) {
        final t = m.at(x, y);
        final r = Rect.fromLTWH(x * cell, y * cell, cell + 0.3, cell + 0.3);
        if (t == Tile.wall) {
          canvas.drawRect(r, wall);
        } else if (t == Tile.door) {
          canvas.drawRect(r.deflate(cell * 0.3), door);
        } else if (s.minimapShowsTrail &&
            (t == Tile.pellet || t == Tile.power)) {
          canvas.drawCircle(
            r.center,
            cell * (t == Tile.power ? 0.35 : 0.15),
            pellet,
          );
        }
      }
    }

    if (s.difficulty != Difficulty.hell) {
      for (final g in s.aiGhosts) {
        if (g.state == GhostState.inHouse) continue;
        canvas.drawCircle(
          Offset(g.x(m) * cell, g.y(m) * cell),
          cell * 0.55,
          Paint()..color = g.frightened ? frightBlue : g.color,
        );
      }
    }

    // You: an arrow pointing where you look.
    if (s.player.state != GhostState.eaten) {
      final c = Offset(s.player.x(m) * cell, s.player.y(m) * cell);
      final r = cell * 1.1;
      final a = camAngle;
      final arrow = Path()
        ..moveTo(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r)
        ..lineTo(c.dx + math.cos(a + 2.5) * r, c.dy + math.sin(a + 2.5) * r)
        ..lineTo(
          c.dx + math.cos(a + math.pi) * r * 0.3,
          c.dy + math.sin(a + math.pi) * r * 0.3,
        )
        ..lineTo(c.dx + math.cos(a - 2.5) * r, c.dy + math.sin(a - 2.5) * r)
        ..close();
      canvas.drawPath(arrow, Paint()..color = s.player.color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
