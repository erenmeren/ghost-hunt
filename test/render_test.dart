import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghost_hunt/game/entities.dart';
import 'package:ghost_hunt/game/fruit.dart';
import 'package:ghost_hunt/game/game_state.dart';
import 'package:ghost_hunt/game/maze.dart';
import 'package:ghost_hunt/ui/minimap_painter.dart';
import 'package:ghost_hunt/ui/raycast_painter.dart';
import 'package:ghost_hunt/ui/top_down_painter.dart';
import 'package:material_ui/material_ui.dart';

/// Renders painters off-screen to make sure they do not throw, and (when
/// RENDER_DIR is set) writes PNGs for eyeballing.
Future<void> render(String name, CustomPainter p, Size size) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  p.paint(canvas, size);
  final pic = rec.endRecording();
  final dir = Platform.environment['RENDER_DIR'];
  if (dir == null) return;
  final img = await pic.toImage(size.width.toInt(), size.height.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

GameState beamScene(Difficulty d, {double beat = 0}) {
  final s = GameState(difficulty: d, seed: 1);
  final m = s.maze;
  // Player in the bottom-left corridor looking right; Pac-Man is behind the
  // wall block above, so only its light can give it away.
  s.player.placeAt(m.index(1, 29), Dir.right);
  s.pac.placeAt(m.index(9, 26), Dir.left);
  s.phase = Phase.playing;
  s.excitement = 0.8;
  // Advance animation clock to a heart beat peak.
  s.update(beat);
  return s;
}

void main() {
  test('painters render all modes', () async {
    const view = Size(844, 390);
    for (final d in Difficulty.values) {
      final s = beamScene(d);
      final m = s.maze;
      final cam = Camera(s.player.x(m), s.player.y(m), s.player.dir.angle);
      await render('ray_${d.name}', RaycastPainter(s, cam), view);
      await render(
        'map_${d.name}',
        MinimapPainter(s, cam.angle),
        const Size(220, 244),
      );
      await render('top_${d.name}', TopDownPainter(s), view);
    }
    final s = beamScene(Difficulty.hard);
    s.pac.placeAt(s.maze.index(7, 29), Dir.right);
    s.aiGhosts[0].placeAt(s.maze.index(10, 29), Dir.left);
    s.aiGhosts[0].state = GhostState.active;
    final m = s.maze;
    final cam = Camera(s.player.x(m), s.player.y(m), s.player.dir.angle);
    await render('ray_pac_in_view', RaycastPainter(s, cam), view);

    // Fruit and the side tunnel.
    s.fruit = Fruit(FruitType.pumpkin, m.fruitTile, 9);
    s.player.placeAt(m.index(0, 12), Dir.left);
    await render('top_fruit', TopDownPainter(s), const Size(560, 620));
    await render('map_fruit', MinimapPainter(s, 0), const Size(220, 244));
    await render(
      'ray_fruit',
      RaycastPainter(
        s,
        Camera(m.xOf(m.fruitTile) - 2.5, m.yOf(m.fruitTile) + 0.5, 0),
      ),
      view,
    );
    await render(
      'ray_tunnel',
      RaycastPainter(s, Camera(4.5, 12.5, Dir.left.angle)),
      view,
    );
  });

  test('heart beat rises and falls', () {
    final s = GameState(difficulty: Difficulty.hard, seed: 1)..excitement = 1;
    final samples = <double>[];
    for (var i = 0; i < 120; i++) {
      s.update(1 / 60);
      samples.add(s.beatIntensity);
    }
    final hi = samples.reduce((a, b) => a > b ? a : b);
    final lo = samples.reduce((a, b) => a < b ? a : b);
    expect(hi - lo, greaterThan(0.5));
  });
}
