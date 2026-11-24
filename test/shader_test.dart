import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghost_hunt/game/fruit.dart';
import 'package:ghost_hunt/game/game_state.dart';
import 'package:ghost_hunt/game/maze.dart';
import 'package:ghost_hunt/ui/raycast_painter.dart';
import 'package:ghost_hunt/ui/shader_scene.dart';
import 'package:material_ui/material_ui.dart';

/// Renders the GPU 3D scene off-screen. With RENDER_DIR set, writes PNGs.
Future<ui.Image> shot(
  Scene3D scene,
  GameState s,
  Camera cam,
  View3D v,
  String name,
) async {
  const size = Size(480, 270);
  // First paint kicks off the async maze texture upload.
  ShaderScenePainter(
    scene,
    s,
    cam,
    v,
  ).paint(Canvas(ui.PictureRecorder()), size);
  for (var i = 0; i < 20 && !scene.ready; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  final rec = ui.PictureRecorder();
  ShaderScenePainter(scene, s, cam, v).paint(Canvas(rec), size);
  final img = await rec.endRecording().toImage(480, 270);
  final dir = Platform.environment['RENDER_DIR'];
  if (dir != null) {
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  }
  return img;
}

/// Brightness spread: a flat image (broken shader) has ~0.
Future<double> contrast(ui.Image img) async {
  final d = (await img.toByteData())!;
  var lo = 255, hi = 0;
  for (var i = 0; i < d.lengthInBytes; i += 4 * 7) {
    final l = (d.getUint8(i) + d.getUint8(i + 1) + d.getUint8(i + 2)) ~/ 3;
    lo = math.min(lo, l);
    hi = math.max(hi, l);
  }
  return (hi - lo).toDouble();
}

/// Red level around the point where the fruit/tunnel end is drawn.
Future<int> middleRed(ui.Image img) async {
  final d = (await img.toByteData())!;
  var hi = 0;
  for (var y = 130; y < 170; y += 2) {
    for (var x = 232; x < 248; x += 2) {
      hi = math.max(hi, d.getUint8((y * img.width + x) * 4));
    }
  }
  return hi;
}

void main() {
  testWidgets('3D shader scene renders a real picture', (tester) async {
    await tester.runAsync(() async {
      final scene = await Scene3D.load();
      if (scene == null) {
        markTestSkipped('fragment shaders unsupported here');
        return;
      }
      for (final d in [Difficulty.hard, Difficulty.hell]) {
        final s = GameState(difficulty: d, seed: 1);
        final m = s.maze;
        s.player.placeAt(m.index(1, 29), Dir.right);
        s.pac.placeAt(m.index(6, 29), Dir.left);
        s.phase = Phase.playing;
        s.excitement = 0.8;
        s.update(0.01);
        final cam = Camera(1.5, 29.5, 0);
        final v = View3D();
        final img = await shot(scene, s, cam, v, '3d_${d.name}');
        expect(await contrast(img), greaterThan(40), reason: d.name);
        // From above (jump/flight preview).
        v
          ..eyeHeight = 2.0
          ..pitch = -0.35;
        await shot(scene, s, cam, v, '3d_${d.name}_high');

        // Fruit ahead, then the dark end of the side tunnel.
        final level = View3D();
        final seen = await shot(
          scene,
          s..fruit = Fruit(FruitType.melon, m.fruitTile, 9),
          Camera(m.xOf(m.fruitTile) - 2.5, m.yOf(m.fruitTile) + 0.5, 0),
          level,
          '3d_${d.name}_fruit',
        );
        final gone = await shot(
          scene,
          s..fruit = null,
          Camera(m.xOf(m.fruitTile) - 2.5, m.yOf(m.fruitTile) + 0.5, 0),
          level,
          '3d_${d.name}_nofruit',
        );
        expect(await middleRed(seen), greaterThan(await middleRed(gone) + 30));
        final tunnel = await shot(
          scene,
          s,
          Camera(4.5, 12.5, math.pi),
          level,
          '3d_${d.name}_tunnel',
        );
        expect(await middleRed(tunnel), lessThan(60));
      }
    });
  });
}
