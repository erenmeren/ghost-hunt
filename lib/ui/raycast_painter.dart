import 'dart:math' as math;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../game/entities.dart';
import '../game/game_state.dart';
import '../game/maze.dart';
import 'sprites.dart';
import 'wall_art.dart';

/// Camera for the first-person view (world units = tiles).
class Camera {
  Camera(this.x, this.y, this.angle);
  double x, y, angle;
  double bob = 0;
}

/// Wolfenstein-style raycaster: the maze seen through the player ghost's eyes.
class RaycastPainter extends CustomPainter {
  RaycastPainter(this.s, this.cam);

  final GameState s;
  final Camera cam;

  static const _fovPlane = 0.66; // ~66 degree field of view
  static const _fogDist = 15.0;
  static const _wallAboveEye = 0.32; // wall top above eye, in tile heights

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final m = s.maze;
    final horizon = h / 2 + cam.bob;

    // Ceiling and floor.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizon),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF000000), Color(0xFF05051C)],
        ).createShader(Rect.fromLTWH(0, 0, w, horizon)),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, w, h - horizon),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF03030F), Color(0xFF0D0D33)],
        ).createShader(Rect.fromLTWH(0, horizon, w, h - horizon)),
    );

    final dirX = math.cos(cam.angle), dirY = math.sin(cam.angle);
    final planeX = -dirY * _fovPlane, planeY = dirX * _fovPlane;
    final strip = math.max(2.0, w / 400);
    final n = (w / strip).ceil();
    final zbuf = Float64List(n);
    final wallTop = Float64List(n);

    final fillPaint = Paint();
    final edgePaint = Paint();

    for (var i = 0; i < n; i++) {
      final camX = 2 * (i + 0.5) / n - 1;
      final rayX = dirX + planeX * camX, rayY = dirY + planeY * camX;
      var mapX = cam.x.floor(), mapY = cam.y.floor();
      final deltaX = rayX == 0 ? 1e30 : (1 / rayX).abs();
      final deltaY = rayY == 0 ? 1e30 : (1 / rayY).abs();
      final stepX = rayX < 0 ? -1 : 1, stepY = rayY < 0 ? -1 : 1;
      var sideX = rayX < 0
          ? (cam.x - mapX) * deltaX
          : (mapX + 1 - cam.x) * deltaX;
      var sideY = rayY < 0
          ? (cam.y - mapY) * deltaY
          : (mapY + 1 - cam.y) * deltaY;
      var side = 0;
      var tile = Tile.wall;
      for (var guard = 0; guard < 64; guard++) {
        if (sideX < sideY) {
          sideX += deltaX;
          mapX += stepX;
          side = 0;
        } else {
          sideY += deltaY;
          mapY += stepY;
          side = 1;
        }
        tile = m.at(mapX, mapY);
        if (tile == Tile.wall || tile == Tile.door) break;
      }
      final perp = math.max(0.05, side == 0 ? sideX - deltaX : sideY - deltaY);
      var wallX = side == 0 ? cam.y + perp * rayY : cam.x + perp * rayX;
      wallX -= wallX.floor();

      final lh = h / perp;
      // Walls are a bit taller than the ghost's eyes: you can't see over
      // them, but there is sky above where Pac-Man's light shows.
      final top = horizon - lh * _wallAboveEye;
      final wallH = lh * (0.5 + _wallAboveEye);
      zbuf[i] = perp;
      wallTop[i] = top;
      final fog = (1 - perp / _fogDist).clamp(0.06, 1.0);
      final shade = (side == 1 ? 0.78 : 1.0) * fog;
      final x0 = i * strip;

      if (tile == Tile.door) {
        fillPaint.color = Color.lerp(Colors.black, gateColor, shade * 0.8)!;
        canvas.drawRect(
          Rect.fromLTWH(x0, horizon - lh * 0.08, strip + 0.5, lh * 0.16),
          fillPaint,
        );
        continue;
      }

      // The side tunnel ends in darkness, not in a wall.
      if (mapX < 0 || mapX >= m.width) {
        fillPaint.color = const Color(0xFF010104);
        canvas.drawRect(Rect.fromLTWH(x0, top, strip + 0.5, wallH), fillPaint);
        continue;
      }

      // Dark body with neon top and bottom edges.
      fillPaint.color = Color.lerp(
        Colors.black,
        const Color(0xFF1C1458),
        shade,
      )!;
      canvas.drawRect(Rect.fromLTWH(x0, top, strip + 0.5, wallH), fillPaint);
      edgePaint.color = Color.lerp(Colors.black, neonColor, shade)!;
      final edgeH = math.max(1.5, wallH * 0.035);
      canvas.drawRect(Rect.fromLTWH(x0, top, strip + 0.5, edgeH), edgePaint);
      canvas.drawRect(
        Rect.fromLTWH(x0, top + wallH - edgeH, strip + 0.5, edgeH),
        edgePaint,
      );

      // Bright vertical lines on outside corners of wall blocks.
      final nearEdge = wallX < 0.04 || wallX > 0.96;
      if (nearEdge) {
        final lowSide = wallX < 0.5;
        final ax = side == 0 ? mapX : mapX + (lowSide ? -1 : 1);
        final ay = side == 0 ? mapY + (lowSide ? -1 : 1) : mapY;
        if (!m.isWallXY(ax, ay)) {
          canvas.drawRect(
            Rect.fromLTWH(x0, top, strip + 0.5, wallH),
            edgePaint,
          );
        }
      }
    }

    // ------------------------------------------------------------ sprites
    final invDet = 1 / (planeX * dirY - dirX * planeY);
    (double, double)? project(double wx, double wy) {
      final rx = wx - cam.x, ry = wy - cam.y;
      final tx = invDet * (dirY * rx - dirX * ry);
      final ty = invDet * (-planeY * rx + planeX * ry);
      if (ty < 0.15) return null;
      return (w / 2 * (1 + tx / ty), ty);
    }

    int col(double sx) => (sx / strip).floor().clamp(0, n - 1);

    // Pellets close by (cheap: only within fog range).
    final pelletPaint = Paint()..color = wispColor;
    final blink = (s.clock * 3).floor().isEven;
    final r0 = _fogDist.ceil();
    for (
      var y = math.max(0, cam.y.floor() - r0);
      y < math.min(m.height, cam.y.floor() + r0);
      y++
    ) {
      for (
        var x = math.max(0, cam.x.floor() - r0);
        x < math.min(m.width, cam.x.floor() + r0);
        x++
      ) {
        final t = m.at(x, y);
        if (t != Tile.pellet && t != Tile.power) continue;
        if (t == Tile.power && !blink) continue;
        final p = project(x + 0.5, y + 0.5);
        if (p == null) continue;
        final (sx, ty) = p;
        if (sx < -20 || sx > w + 20) continue;
        if (zbuf[col(sx)] < ty) continue;
        final scale = h / ty;
        final fog = (1 - ty / _fogDist).clamp(0.1, 1.0);
        pelletPaint.color = wispColor.withValues(alpha: fog);
        canvas.drawCircle(
          Offset(sx, horizon + scale * 0.2),
          scale * (t == Tile.power ? 0.1 : 0.03),
          pelletPaint,
        );
      }
    }

    // ---------------------------------------------- Pac-Man's light beam
    final pac = project(s.pac.x(m), s.pac.y(m));
    if (s.showBeam && pac != null) {
      final (sx, ty) = pac;
      final scale = h / ty;
      final bw = (scale * 0.5).clamp(9.0, w * 0.25);
      final base = horizon + scale * 0.15; // from Pac-Man's centre up
      // The glow only lives in the sky above the walls; the thin core may
      // come down to Pac-Man himself when nothing is in between.
      final sky = Path(), core = Path();
      final c0 = ((sx - bw * 3) / strip).floor();
      final c1 = ((sx + bw * 3) / strip).ceil();
      for (var i = math.max(0, c0); i <= math.min(n - 1, c1); i++) {
        final col = Rect.fromLTWH(i * strip, 0, strip + 0.5, wallTop[i]);
        if (wallTop[i] > 0) sky.addRect(col);
        final bottom = zbuf[i] > ty ? base : wallTop[i];
        if (bottom > 0) {
          core.addRect(Rect.fromLTWH(i * strip, 0, strip + 0.5, bottom));
        }
      }
      // Never fully dark, so it can always be found; the beat is on top.
      final glow = 0.3 + 0.7 * s.beatIntensity;
      Shader vertical(Color c, double aTop, double aBottom) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          c.withValues(alpha: aTop),
          c.withValues(alpha: aBottom),
        ],
      ).createShader(Rect.fromLTRB(0, 0, 1, base));
      canvas.save();
      canvas.clipPath(sky);
      // Wide soft halo.
      canvas.drawRect(
        Rect.fromLTRB(sx - bw * 2, 0, sx + bw * 2, base),
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, bw)
          ..shader = vertical(pacYellow, 0.0, 0.45 * glow),
      );
      // Beam body.
      canvas.drawRect(
        Rect.fromLTRB(sx - bw * 0.6, 0, sx + bw * 0.6, base),
        Paint()
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, bw * 0.35)
          ..shader = vertical(pacYellow, 0.1 * glow, 0.9 * glow),
      );
      canvas.restore();
      canvas.save();
      canvas.clipPath(core);
      // Hot core.
      canvas.drawRect(
        Rect.fromLTRB(sx - bw * 0.15, 0, sx + bw * 0.15, base),
        Paint()..shader = vertical(const Color(0xFFFFFFD0), 0.0, glow),
      );
      canvas.restore();

      // Light spilling over the top edge of the walls in front of it.
      final spill = Paint()..strokeWidth = 3;
      for (var i = math.max(0, c0); i <= math.min(n - 1, c1); i++) {
        if (zbuf[i] > ty) continue;
        final x = (i + 0.5) * strip;
        final f = 1 - ((x - sx).abs() / (bw * 3)).clamp(0.0, 1.0);
        if (f <= 0) continue;
        spill.color = pacYellow.withValues(alpha: f * f * glow);
        canvas.drawLine(
          Offset(i * strip, wallTop[i]),
          Offset(i * strip + strip + 0.5, wallTop[i]),
          spill,
        );
      }
    }

    // Ghost teammates and Pac-Man, far to near, clipped by the z-buffer.
    final sprites = <_Sprite>[];
    final flashing = s.frightTimer < 2 && (s.clock * 5).floor().isEven;
    for (final g in s.aiGhosts) {
      final p = project(g.x(m), g.y(m));
      if (p == null) continue;
      final (sx, ty) = p;
      final look = g.dir.angle - cam.angle;
      sprites.add(
        _Sprite(sx, ty, (c, sx, scale) {
          final bob = math.sin(s.clock * 5 + g.spawnTile) * scale * 0.03;
          drawGhost(
            c,
            Offset(sx, horizon + scale * 0.15 + bob),
            scale * 0.33,
            color: g.color,
            frightened: g.frightened,
            flashing: flashing,
            eyesOnly: g.state == GhostState.eaten,
            lookX: math.sin(look),
            wobble: s.clock * 4,
            alpha: (1.5 - ty / _fogDist).clamp(0.2, 1.0),
          );
        }),
      );
    }
    final fruit = s.fruit;
    final fp = fruit == null
        ? null
        : project(m.xOf(fruit.tile) + 0.5, m.yOf(fruit.tile) + 0.5);
    if (fruit != null && fp != null) {
      final (sx, ty) = fp;
      sprites.add(
        _Sprite(sx, ty, (c, sx, scale) {
          final bob = math.sin(s.clock * 4) * scale * 0.02;
          final at = Offset(sx, horizon + scale * 0.2 + bob);
          c.drawCircle(
            at,
            scale * 0.26,
            Paint()
              ..color = fruitColor(fruit.type).withValues(alpha: 0.35)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * 0.08),
          );
          drawFruit(c, at, scale * 0.18, fruit.type);
        }),
      );
    }
    final pp = project(s.pac.x(m), s.pac.y(m));
    if (pp != null) {
      final (sx, ty) = pp;
      sprites.add(
        _Sprite(sx, ty, (c, sx, scale) {
          // He looks left/right on screen depending on his heading.
          final rel = s.pac.dir.angle - cam.angle;
          final facing = math.sin(rel) >= 0 ? 0.0 : math.pi;
          drawRunner(
            c,
            Offset(sx, horizon + scale * 0.15),
            scale * 0.33,
            s.pac.mouthOpen,
            facing: facing,
            alpha: (1.6 - ty / _fogDist).clamp(0.25, 1.0),
          );
        }),
      );
    }
    sprites.sort((a, b) => b.depth.compareTo(a.depth));
    for (final sp in sprites) {
      final scale = h / sp.depth;
      final half = scale * 0.4;
      if (sp.sx + half < 0 || sp.sx - half > w) continue;
      final clip = Path();
      var any = false;
      for (
        var i = math.max(0, ((sp.sx - half) / strip).floor());
        i <= math.min(n - 1, ((sp.sx + half) / strip).ceil());
        i++
      ) {
        if (zbuf[i] > sp.depth) {
          clip.addRect(Rect.fromLTWH(i * strip, 0, strip + 0.5, h));
          any = true;
        }
      }
      if (!any) continue;
      canvas.save();
      canvas.clipPath(clip);
      sp.draw(canvas, sp.sx, scale);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _Sprite {
  _Sprite(this.sx, this.depth, this.draw);
  final double sx;
  final double depth;
  final void Function(Canvas c, double sx, double scale) draw;
}
