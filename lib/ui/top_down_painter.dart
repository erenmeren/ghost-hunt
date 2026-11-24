import 'package:material_ui/material_ui.dart';

import '../game/entities.dart';
import '../game/game_state.dart';
import '../game/maze.dart';
import 'arcade_layout.dart';
import 'sprites.dart';
import 'wall_art.dart';

/// Accent colour of menus and cards.
const wallBlue = Color(0xFF2121DE);

/// Overhead view used by Easy mode.
class TopDownPainter extends CustomPainter {
  TopDownPainter(this.s, {this.safe = EdgeInsets.zero});

  final GameState s;

  /// Screen edges to keep clear (notches).
  final EdgeInsets safe;

  @override
  void paint(Canvas canvas, Size size) {
    final m = s.maze;
    final layout = ArcadeLayout(size, m, safe);
    final cell = layout.cell, field = layout.field;
    final ox = field.left, oy = field.top;
    Offset at(double x, double y) => Offset(ox + x * cell, oy + y * cell);

    canvas.save();
    canvas.clipRect(field);
    canvas.drawRect(field, Paint()..color = floorColor);

    // Walls and gate: one cached picture in tile units.
    canvas.save();
    canvas.translate(ox, oy);
    canvas.scale(cell);
    canvas.drawPicture(WallArt.of(m).picture);
    canvas.restore();

    // Small square pellets; power pellets blink at 4 Hz during play.
    final wisp = Paint()..color = wispColor;
    final blink = (s.clock * 8).floor().isEven || s.phase != Phase.playing;
    final dots = Path();
    for (var i = 0; i < m.tiles.length; i++) {
      final t = m.tiles[i];
      if (t != Tile.pellet && t != Tile.power) continue;
      final c = at(m.xOf(i) + 0.5, m.yOf(i) + 0.5);
      if (t == Tile.power) {
        if (blink) canvas.drawCircle(c, cell * 0.375, wisp);
      } else {
        dots.addRect(Rect.fromCircle(center: c, radius: cell * 0.125));
      }
    }
    canvas.drawPath(dots, wisp);

    final fruit = s.fruit;
    if (fruit != null) {
      drawFruit(
        canvas,
        at(m.xOf(fruit.tile) + 0.5, m.yOf(fruit.tile) + 0.5),
        cell * 0.75,
        fruit.type,
      );
    }

    // Actors in the side tunnel show on both edges at once.
    void wrapped(double x, double y, void Function(Offset) draw) {
      draw(at(x, y));
      if (x < 1.5) draw(at(x + m.width, y));
      if (x > m.width - 1.5) draw(at(x - m.width, y));
    }

    // Ghosts.
    for (final g in s.ghosts) {
      if (!g.visible) continue;
      final flashing = s.frightTimer < 2 && (s.clock * 5).floor().isEven;
      wrapped(g.x(m), g.y(m), (c) {
        drawGhost(
          canvas,
          c,
          cell * 0.8,
          color: g.color,
          frightened: g.frightened,
          flashing: flashing,
          eyesOnly: g.state == GhostState.eaten,
          lookX: g.dir.dx.toDouble(),
          lookY: g.dir.dy.toDouble(),
          wobble: s.clock * 4,
          // "You" burn brighter and pulse.
          pulse: g.isPlayer ? playerPulse(s.clock) : null,
        );
      });
    }

    // The runner.
    if (s.phase != Phase.caught || (s.clock * 6).floor().isEven) {
      wrapped(
        s.pac.x(m),
        s.pac.y(m),
        (c) => drawRunner(
          canvas,
          c,
          cell * 0.75,
          s.pac.mouthOpen,
          facing: s.pac.dir.angle,
        ),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
