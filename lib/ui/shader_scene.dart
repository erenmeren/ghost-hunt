import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../game/entities.dart';
import '../game/game_state.dart';
import '../game/maze.dart';
import 'raycast_painter.dart' show Camera;
import 'sprites.dart';

/// GPU 3D renderer: loads `shaders/scene.frag` once, keeps a 1-texel-per-tile
/// maze texture in sync, and feeds the camera/actors as uniforms.
class Scene3D {
  Scene3D._(this._program);

  final ui.FragmentProgram _program;
  late final ui.FragmentShader shader = _program.fragmentShader();
  ui.Image? _maze;
  int _mazeVersion = -1;
  Maze? _mazeOf;
  bool _building = false;

  static Future<Scene3D>? _loading;

  /// `?renderer=ray` in the web URL (or [enabled] = false in tests) keeps the
  /// old raycaster.
  static bool enabled = Uri.base.queryParameters['renderer'] != 'ray';

  /// Null when shaders are unavailable (e.g. very old browser): the caller
  /// then falls back to the raycaster.
  static Future<Scene3D?> load() async {
    try {
      return await (_loading ??= ui.FragmentProgram.fromAsset(
        'shaders/scene.frag',
      ).then(Scene3D._));
    } catch (e) {
      debugPrint('3D shader unavailable: $e');
      return null;
    }
  }

  /// Rebuild the maze texture after a pellet is eaten (28x31: trivially cheap).
  void sync(Maze m) {
    final version = m.pelletsLeft;
    if (_building || (identical(m, _mazeOf) && version == _mazeVersion)) {
      return;
    }
    _building = true;
    final px = Uint8List(m.width * m.height * 4);
    for (var i = 0; i < m.width * m.height; i++) {
      final t = m.tileAt(i);
      px[i * 4] = t == Tile.wall ? 255 : 0;
      px[i * 4 + 1] = switch (t) {
        Tile.pellet => 255,
        Tile.power => 128,
        _ => 0,
      };
      px[i * 4 + 2] = t == Tile.door ? 255 : 0;
      px[i * 4 + 3] = 255;
    }
    ui.decodeImageFromPixels(px, m.width, m.height, ui.PixelFormat.rgba8888, (
      img,
    ) {
      // The previous texture may still be referenced by a frame that the
      // web renderer has not rasterised yet: free it a little later.
      final old = _maze;
      if (old != null) {
        Future.delayed(const Duration(milliseconds: 500), old.dispose);
      }
      _maze = img;
      _mazeOf = m;
      _mazeVersion = version;
      _building = false;
    });
  }

  bool get ready => _maze != null;
}

/// Extra camera state for the 3D view.
class View3D {
  double eyeHeight = 0.5; // walls are 0.85 high: you can't see over them
  double pitch = 0;
}

class ShaderScenePainter extends CustomPainter {
  ShaderScenePainter(this.scene, this.s, this.cam, this.view);

  final Scene3D scene;
  final GameState s;
  final Camera cam;
  final View3D view;

  @override
  void paint(Canvas canvas, Size size) {
    final m = s.maze;
    scene.sync(m);
    final img = scene._maze;
    if (img == null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
      return;
    }
    final sh = scene.shader;
    var i = 0;
    void f(double v) => sh.setFloat(i++, v);

    f(size.width);
    f(size.height);
    // Camera (bob is in pixels in the 2D view; here a little head bob).
    f(cam.x);
    f(cam.y);
    f(view.eyeHeight + cam.bob * 0.004);
    f(cam.angle);
    f(view.pitch);
    f(s.clock);
    f(s.difficulty == Difficulty.hell ? 1 : 0);
    f(s.difficulty == Difficulty.easy ? 0 : s.beatIntensity);
    // Pac-Man.
    final pac = s.pac;
    f(pac.x(m));
    f(pac.y(m));
    f(pac.dir == Dir.none ? cam.angle + math.pi : pac.dir.angle);
    f(pac.mouthOpen);
    f(s.showBeam ? 1 : 0);
    f(s.frightTimer > 0 ? 1 : 0);
    f(1); // pac visible
    f(0.9); // zoom (focal length): ~74° vertical-ish FOV
    // Up to three team-mate ghosts.
    final others = s.aiGhosts;
    final flashing = s.frightTimer < 2 && (s.clock * 5).floor().isEven;
    for (var k = 0; k < 3; k++) {
      if (k >= others.length || !others[k].visible) {
        for (var j = 0; j < 8; j++) {
          f(0);
        }
        continue;
      }
      final g = others[k];
      f(g.x(m));
      f(g.y(m));
      f(g.dir == Dir.none ? 0 : g.dir.angle);
      f(g.state == GhostState.eaten ? 2 : 1);
      final c = g.frightened ? frightBlue : g.color;
      f(c.r);
      f(c.g);
      f(c.b);
      f(g.frightened && flashing ? 1 : 0);
    }
    f(m.width.toDouble());
    f(m.height.toDouble());
    sh.setImageSampler(0, img);

    canvas.drawRect(Offset.zero & size, Paint()..shader = sh);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
