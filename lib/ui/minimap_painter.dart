import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../game/entities.dart';
import '../game/game_state.dart';
import '../game/maze.dart';
import 'sprites.dart';
import 'wall_art.dart';

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
    // Same traced outlines as the overhead view, one pixel thin.
    final art = WallArt.of(m);
    canvas.save();
    canvas.scale(cell);
    canvas.drawPath(
      art.walls,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 / cell
        ..color = neonColor.withValues(alpha: 0.9),
    );
    canvas.drawPath(art.gates, Paint()..color = gateColor);
    canvas.restore();

    if (s.minimapShowsTrail) {
      final pelletPaint = Paint()..color = pelletColor.withValues(alpha: 0.8);
      for (var i = 0; i < m.tiles.length; i++) {
        final t = m.tiles[i];
        if (t != Tile.pellet && t != Tile.power) continue;
        final c = Offset((m.xOf(i) + 0.5) * cell, (m.yOf(i) + 0.5) * cell);
        t == Tile.power
            ? canvas.drawCircle(c, cell * 0.375, pelletPaint)
            : canvas.drawRect(
                Rect.fromCircle(center: c, radius: cell * 0.125),
                pelletPaint,
              );
      }
    }

    final fruit = s.fruit;
    if (fruit != null && s.minimapShowsFruit) {
      canvas.drawCircle(
        Offset(
          (m.xOf(fruit.tile) + 0.5) * cell,
          (m.yOf(fruit.tile) + 0.5) * cell,
        ),
        cell * 0.6,
        Paint()..color = fruitColor(fruit.type),
      );
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

    if (s.minimapShowsPac) {
      canvas.drawCircle(
        Offset(s.pac.x(m) * cell, s.pac.y(m) * cell),
        cell * 0.8,
        Paint()..color = pacYellow,
      );
    }

    // You: a bright pulsing arrow pointing where you look.
    if (s.player.state != GhostState.eaten) {
      final c = Offset(s.player.x(m) * cell, s.player.y(m) * cell);
      final r = cell * 1.1;
      final a = camAngle;
      final pulse = playerPulse(s.clock);
      drawPlayerGlow(canvas, c, r, vividColor(s.player.color, 0), pulse);
      final arrow = Path()
        ..moveTo(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r)
        ..lineTo(c.dx + math.cos(a + 2.5) * r, c.dy + math.sin(a + 2.5) * r)
        ..lineTo(
          c.dx + math.cos(a + math.pi) * r * 0.3,
          c.dy + math.sin(a + math.pi) * r * 0.3,
        )
        ..lineTo(c.dx + math.cos(a - 2.5) * r, c.dy + math.sin(a - 2.5) * r)
        ..close();
      canvas.drawPath(
        arrow,
        Paint()..color = vividColor(s.player.color, pulse),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
