import 'dart:math' as math;
import 'dart:ui';

import '../game/maze.dart';

/// Ghost Hunt's own arcade palette: violet neon on black, pellets, gold.
const floorColor = Color(0xFF000000);
const neonColor = Color(0xFF8B6CFF);
const gateColor = Color(0xFFE8C46A);

/// Static maze walls, traced once per maze in tile units. Draw them under a
/// scaled canvas: nothing has to be rebuilt when the window is resized.
class WallArt {
  WallArt._(this.walls, this.gates);

  /// Thin outlines (stroke only): one closed loop per inner island, two
  /// parallel lines along the outer border.
  final Path walls;

  /// Ghost-house door bar.
  final Path gates;

  static final _cache = Expando<WallArt>();
  static WallArt of(Maze m) => _cache[m] ??= _trace(m);

  /// Line thickness in tiles.
  static const lineWidth = 1 / 8;

  static const _inset = 0.29; // how far lines sit inside the wall
  static const _borderInset = 0.66; // second line of the outer border
  static const _radius = 0.4;
  static const _edgeGap = 0.02; // border lines stop just short of the edge

  /// Full-detail picture for the overhead view (tile units).
  late final Picture picture = _record();

  Picture _record() {
    final rec = PictureRecorder();
    final c = Canvas(rec);
    c.drawPath(
      walls,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth
        ..color = neonColor,
    );
    c.drawPath(gates, Paint()..color = gateColor);
    return rec.endRecording();
  }

  static WallArt _trace(Maze m) {
    bool solid(int x, int y) =>
        x >= 0 &&
        y >= 0 &&
        x < m.width &&
        y < m.height &&
        m.at(x, y) == Tile.wall;

    // Directed boundary edges between lattice points, wall on the right.
    // Edges on the rim of the field are left out: there the border is open
    // to the outside, so its contour becomes an open line (or, without a
    // side tunnel, a closed inner loop).
    final stride = m.width + 1;
    int key(int x, int y) => y * stride + x;
    final out = <int, List<Dir>>{};
    final incoming = <int>{};
    void edge(int x, int y, Dir d) {
      (out[key(x, y)] ??= []).add(d);
      incoming.add(key(x + d.dx, y + d.dy));
    }

    for (var y = 0; y < m.height; y++) {
      for (var x = 0; x < m.width; x++) {
        if (!solid(x, y)) continue;
        if (y > 0 && !solid(x, y - 1)) edge(x, y, Dir.right);
        if (x < m.width - 1 && !solid(x + 1, y)) edge(x + 1, y, Dir.down);
        if (y < m.height - 1 && !solid(x, y + 1)) {
          edge(x + 1, y + 1, Dir.left);
        }
        if (x > 0 && !solid(x - 1, y)) edge(x, y + 1, Dir.up);
      }
    }

    // Tiles of wall masses that touch the rim get the double line.
    final border = _borderTiles(m);
    bool isBorder(int at, Dir d) {
      // The wall tile on the right-hand side of the edge leaving [at].
      final x = at % stride, y = at ~/ stride;
      final (tx, ty) = switch (d) {
        Dir.right => (x, y),
        Dir.down => (x - 1, y),
        Dir.left => (x - 1, y - 1),
        _ => (x, y - 1),
      };
      return border.contains(m.index(tx, ty));
    }

    final walls = Path();
    void walk(int start, {required bool open}) {
      var at = start;
      var dir = out[at]!.first;
      final doubled = isBorder(at, dir);
      final pts = <Offset>[];
      final dirs = <Dir>[]; // direction leaving pts[i]
      Offset point(int k) =>
          Offset((k % stride).toDouble(), (k ~/ stride).toDouble());
      while (out.containsKey(at)) {
        final here = out[at]!;
        // Where two masses touch diagonally, keep to the same mass.
        final next = here.contains(dir.turnRight) ? dir.turnRight : here.first;
        here.remove(next);
        if (here.isEmpty) out.remove(at);
        if (dirs.isEmpty || next != dirs.last) {
          pts.add(point(at));
          dirs.add(next);
        }
        dir = next;
        at += dir.dx + dir.dy * stride;
        if (!open && at == start) break;
      }
      if (open) {
        pts.add(point(at));
      } else if (dirs.length > 1 && dirs.first == dirs.last) {
        // Start the loop at its first real corner.
        pts.removeAt(0);
        dirs.removeAt(0);
      }
      for (final inset in [_inset, if (doubled) _borderInset]) {
        // The outer line turns wider corners so the pair stays parallel.
        final r = inset == _inset ? _radius : _radius + 0.1;
        open
            ? _addOpen(walls, pts, dirs, inset, r, m)
            : _addClosed(walls, pts, dirs, inset, r);
      }
    }

    // Open lines first (they start where nothing leads in), then loops.
    for (final k in out.keys.where((k) => !incoming.contains(k)).toList()) {
      walk(k, open: true);
    }
    while (out.isNotEmpty) {
      walk(out.keys.first, open: false);
    }

    final gates = Path();
    for (var i = 0; i < m.tiles.length; i++) {
      if (m.tiles[i] != Tile.door) continue;
      gates.addRect(Rect.fromLTWH(m.xOf(i).toDouble(), m.yOf(i) + 0.4, 1, 0.2));
    }
    return WallArt._(walls, gates);
  }

  /// Every wall tile connected to the rim of the field.
  static Set<int> _borderTiles(Maze m) {
    final seen = <int>{};
    final todo = <int>[
      for (var i = 0; i < m.tiles.length; i++)
        if (m.xOf(i) == 0 ||
            m.yOf(i) == 0 ||
            m.xOf(i) == m.width - 1 ||
            m.yOf(i) == m.height - 1)
          i,
    ];
    while (todo.isNotEmpty) {
      final i = todo.removeLast();
      if (m.tiles[i] != Tile.wall || !seen.add(i)) continue;
      final x = m.xOf(i), y = m.yOf(i);
      for (final d in moveDirs) {
        if (m.isWallXY(x + d.dx, y + d.dy) &&
            x + d.dx >= 0 &&
            x + d.dx < m.width &&
            y + d.dy >= 0 &&
            y + d.dy < m.height) {
          todo.add(m.index(x + d.dx, y + d.dy));
        }
      }
    }
    return seen;
  }

  /// One closed axis-aligned loop, pulled [inset] into the wall.
  static void _addClosed(
    Path path,
    List<Offset> pts,
    List<Dir> dirs,
    double inset,
    double radius,
  ) {
    final n = pts.length;
    final p = <Offset>[
      for (var i = 0; i < n; i++)
        pts[i] + (_right(dirs[i]) + _right(dirs[(i + n - 1) % n])) * inset,
    ];
    for (var i = 0; i < n; i++) {
      _corner(
        path,
        p[(i + n - 1) % n],
        p[i],
        p[(i + 1) % n],
        radius,
        first: i == 0,
      );
    }
    path.close();
  }

  /// One open line whose ends run out to the rim of the field.
  static void _addOpen(
    Path path,
    List<Offset> pts,
    List<Dir> dirs,
    double inset,
    double radius,
    Maze m,
  ) {
    Offset clip(Offset o) => Offset(
      o.dx.clamp(_edgeGap, m.width - _edgeGap),
      o.dy.clamp(_edgeGap, m.height - _edgeGap),
    );
    final n = dirs.length;
    final p = <Offset>[
      clip(pts[0] + _right(dirs[0]) * inset),
      for (var i = 1; i < n; i++)
        pts[i] + (_right(dirs[i]) + _right(dirs[i - 1])) * inset,
      clip(pts[n] + _right(dirs[n - 1]) * inset),
    ];
    path.moveTo(p[0].dx, p[0].dy);
    for (var i = 1; i < n; i++) {
      _corner(path, p[i - 1], p[i], p[i + 1], radius);
    }
    path.lineTo(p[n].dx, p[n].dy);
  }

  static void _corner(
    Path path,
    Offset prev,
    Offset cur,
    Offset next,
    double radius, {
    bool first = false,
  }) {
    final a = prev - cur, b = next - cur;
    final r = math.min(radius, math.min(a.distance, b.distance) / 2);
    final from = cur + a / a.distance * r, to = cur + b / b.distance * r;
    first ? path.moveTo(from.dx, from.dy) : path.lineTo(from.dx, from.dy);
    path.quadraticBezierTo(cur.dx, cur.dy, to.dx, to.dy);
  }

  static Offset _right(Dir d) =>
      Offset(d.turnRight.dx.toDouble(), d.turnRight.dy.toDouble());
}
