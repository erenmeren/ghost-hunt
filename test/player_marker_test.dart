import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghost_hunt/game/entities.dart';
import 'package:ghost_hunt/game/game_state.dart';
import 'package:ghost_hunt/game/maze.dart';
import 'package:ghost_hunt/ui/arcade_layout.dart';
import 'package:ghost_hunt/ui/minimap_painter.dart';
import 'package:ghost_hunt/ui/sprites.dart';
import 'package:ghost_hunt/ui/top_down_painter.dart';
import 'package:material_ui/material_ui.dart';

const view = Size(560, 720);
const low = 0.375, high = 0.125; // clock at the dim and bright ends

class Shot {
  Shot(this.width, this.bytes);

  final int width;
  final ByteData bytes;

  Color at(Offset o) {
    final i = (o.dy.round() * width + o.dx.round()) * 4;
    return Color.fromARGB(
      255,
      bytes.getUint8(i),
      bytes.getUint8(i + 1),
      bytes.getUint8(i + 2),
    );
  }
}

Future<Shot> shoot(CustomPainter p, Size size) async {
  final rec = ui.PictureRecorder();
  p.paint(Canvas(rec), size);
  final img = await rec.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
  final data = await img.toByteData();
  return Shot(img.width, data!);
}

double light(Color c) => c.r + c.g + c.b;

/// Player and one AI ghost alone in pellet-free corridors.
GameState scene() {
  final s = GameState(difficulty: Difficulty.easy, seed: 1);
  final m = s.maze;
  for (var i = 0; i < m.tiles.length; i++) {
    if (m.tiles[i] == Tile.pellet || m.tiles[i] == Tile.power) {
      m.tiles[i] = Tile.empty;
    }
  }
  s.phase = Phase.playing;
  s.player
    ..state = GhostState.active
    ..placeAt(m.index(5, 29), Dir.left);
  s.aiGhosts[0]
    ..state = GhostState.active
    ..placeAt(m.index(20, 29), Dir.left);
  return s;
}

void main() {
  test('the pulse runs at 2 Hz and changes brightness', () {
    expect(playerPulse(high), closeTo(1, 1e-9));
    expect(playerPulse(low), closeTo(0, 1e-9));
    expect(playerPulse(high + 0.5), closeTo(1, 1e-9));
    const own = Color(0xFF00E5FF);
    expect(light(vividColor(own, 0)), greaterThan(light(own)));
    expect(
      light(vividColor(own, 1)),
      greaterThan(light(vividColor(own, 0)) + 0.3),
    );
  });

  for (final frightened in [false, true]) {
    test('2D: only the player glows and pulses, no ring '
        '(frightened: $frightened)', () async {
      final s = scene();
      final m = s.maze;
      if (frightened) {
        s.frightTimer = 5;
        s.player.frightened = s.aiGhosts[0].frightened = true;
      }
      final layout = ArcadeLayout(view, m);
      Offset spot(Ghost g, double dx, double dy) =>
          layout.field.topLeft + Offset(g.x(m) + dx, g.y(m) + dy) * layout.cell;
      Future<Shot> frame(double clock) {
        s.clock = clock;
        return shoot(TopDownPainter(s), view);
      }

      final bright = await frame(high), dim = await frame(low);
      // Beside the body, still on the corridor floor.
      double glow(Shot f, Ghost g) => light(f.at(spot(g, -1, 0)));
      expect(glow(bright, s.player), greaterThan(0.1));
      expect(glow(bright, s.player), greaterThan(glow(dim, s.player)));
      expect(glow(bright, s.aiGhosts[0]), 0);
      expect(glow(dim, s.aiGhosts[0]), 0);

      // The body itself brightens; the other ghost stays the same.
      double body(Shot f, Ghost g) => light(f.at(spot(g, 0, 0.44)));
      expect(body(bright, s.player), greaterThan(body(dim, s.player) + 0.2));
      expect(
        body(bright, s.aiGhosts[0]),
        closeTo(body(dim, s.aiGhosts[0]), 0.01),
      );

      // A ring would be a bright step; the glow only ever fades outwards.
      var last = double.infinity;
      for (var d = 0.95; d < 1.9; d += 0.05) {
        final v = light(bright.at(spot(s.player, -d, 0)));
        expect(v, lessThanOrEqualTo(last + 0.02), reason: 'at $d tiles');
        last = v;
      }
    });
  }

  for (final d in [Difficulty.hard, Difficulty.hell]) {
    test('minimap: the player pulses (${d.name})', () async {
      const size = Size(220, 244);
      final s = GameState(difficulty: d, seed: 1)..phase = Phase.playing;
      final m = s.maze;
      s.player.placeAt(m.index(5, 29), Dir.left);
      final cell = size.width / m.width;
      Future<Shot> frame(double clock) {
        s.clock = clock;
        return shoot(MinimapPainter(s, 0), size);
      }

      final bright = await frame(high), dim = await frame(low);
      final c = Offset(s.player.x(m), s.player.y(m)) * cell;
      expect(light(bright.at(c)), greaterThan(light(dim.at(c)) + 0.2));
      // The glow reaches past the arrow.
      final side = c + Offset(0, -cell * 0.75);
      expect(light(bright.at(side)), greaterThan(light(dim.at(side))));

      s.player.frightened = true;
      final scared = await frame(high), scaredDim = await frame(low);
      expect(light(scared.at(c)), greaterThan(light(scaredDim.at(c)) + 0.2));
    });
  }
}
