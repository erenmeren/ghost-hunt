import 'dart:collection';
import 'dart:math' as math;

/// Grid directions. Screen coordinates: x grows right, y grows down.
enum Dir { up, left, down, right, none }

extension DirX on Dir {
  int get dx => switch (this) {
    Dir.left => -1,
    Dir.right => 1,
    _ => 0,
  };

  int get dy => switch (this) {
    Dir.up => -1,
    Dir.down => 1,
    _ => 0,
  };

  Dir get opposite => switch (this) {
    Dir.up => Dir.down,
    Dir.down => Dir.up,
    Dir.left => Dir.right,
    Dir.right => Dir.left,
    Dir.none => Dir.none,
  };

  /// Direction after turning left while facing this way.
  Dir get turnLeft => switch (this) {
    Dir.up => Dir.left,
    Dir.left => Dir.down,
    Dir.down => Dir.right,
    Dir.right => Dir.up,
    Dir.none => Dir.none,
  };

  /// Direction after turning right while facing this way.
  Dir get turnRight => turnLeft.opposite;

  /// Heading angle in radians (right = 0, down = +pi/2).
  double get angle => math.atan2(dy.toDouble(), dx.toDouble());
}

/// Classic tie-break order used by the arcade ghosts.
const List<Dir> moveDirs = [Dir.up, Dir.left, Dir.down, Dir.right];

enum Tile { wall, empty, pellet, power, door, house }

/// The 28x31 layout. Open ends on the left and right edge of one row form a
/// side tunnel: whoever leaves on one side comes back on the other.
///   # wall   . pellet   o power pellet   - ghost door   H ghost house
///   P Pac-Man start   G player ghost start   g AI ghost starts
///   F fruit spot (just below the ghost house)
const List<String> mansionLayout = [
  '############################',
  '#..........................#',
  '#o#########.####.#########o#',
  '#.#########.####.#########.#',
  '#.....##....####....##.....#',
  '#.###.##.##########.##.###.#',
  '#.###.##.##########.##.###.#',
  '#........... ## ...........#',
  '#####.## ### ## ### ##.#####',
  '#####.## ### ## ### ##.#####',
  '#####.##     G      ##.#####',
  '##### ## ####--#### ## #####',
  '         #HgHHgHgH#         ',
  '##### ## #HHHHHHHH# ## #####',
  '#####.## ########## ##.#####',
  '#####.##     F      ##.#####',
  '#####.## ### ## ### ##.#####',
  '#####.## ### ## ### ##.#####',
  '#........... ## ...........#',
  '#.#######.########.#######.#',
  '#.#######.########.#######.#',
  '#.##.......  P   .......##.#',
  '#.##.####.########.####.##.#',
  '#.##.####.########.####.##.#',
  '#............##............#',
  '#.##.##.####.##.####.##.##.#',
  '#....##......##......##....#',
  '#.########.######.########.#',
  '#o########.######.########o#',
  '#..........................#',
  '############################',
];

class Maze {
  Maze._(
    this.width,
    this.height,
    this.tiles,
    this.pacStart,
    this.playerStart,
    this.ghostStarts,
    this.fruitTile,
    this.totalPellets,
  ) : pelletsLeft = totalPellets;

  final int width;
  final int height;
  final List<Tile> tiles;
  final int pacStart;
  final int playerStart;
  final List<int> ghostStarts;

  /// Where the bonus fruit appears.
  final int fruitTile;
  final int totalPellets;
  int pelletsLeft;

  int get pelletsEaten => totalPellets - pelletsLeft;

  /// Tile just outside the ghost door; ghosts leave the house towards it.
  int get houseExit => playerStart;

  /// Middle of the ghost house; eaten ghosts return here.
  int get houseCenter => ghostStarts[1];

  factory Maze.parse(List<String> rows) {
    final h = rows.length;
    final w = rows.first.length;
    final tiles = List<Tile>.filled(w * h, Tile.wall);
    int? pac, player, fruit;
    final ghosts = <int>[];
    for (var y = 0; y < h; y++) {
      final row = rows[y];
      if (row.length != w) {
        throw FormatException('Row $y has length ${row.length}, expected $w');
      }
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        tiles[i] = switch (row[x]) {
          '#' => Tile.wall,
          '.' => Tile.pellet,
          'o' => Tile.power,
          '-' => Tile.door,
          'H' || 'g' => Tile.house,
          _ => Tile.empty,
        };
        switch (row[x]) {
          case 'P':
            pac = i;
          case 'G':
            player = i;
          case 'F':
            fruit = i;
          case 'g':
            ghosts.add(i);
        }
      }
    }
    if (pac == null || player == null || ghosts.isEmpty) {
      throw const FormatException('Layout needs P, G and at least one g');
    }
    // Anything that cannot be reached from the ghost spawn is solid rock.
    final seen = List<bool>.filled(w * h, false);
    final queue = Queue<int>()..add(player);
    seen[player] = true;
    while (queue.isNotEmpty) {
      final c = queue.removeFirst();
      final cx = c % w, cy = c ~/ w;
      for (final d in moveDirs) {
        // Open tiles on both ends of a row are connected (side tunnel).
        final nx = (cx + d.dx) % w, ny = cy + d.dy;
        if (ny < 0 || ny >= h) continue;
        final n = ny * w + nx;
        if (!seen[n] && tiles[n] != Tile.wall) {
          seen[n] = true;
          queue.add(n);
        }
      }
    }
    for (var i = 0; i < tiles.length; i++) {
      if (!seen[i]) tiles[i] = Tile.wall;
    }
    final pellets = tiles
        .where((t) => t == Tile.pellet || t == Tile.power)
        .length;
    return Maze._(w, h, tiles, pac, player, ghosts, fruit ?? pac, pellets);
  }

  factory Maze.classic() => Maze.parse(mansionLayout);

  int xOf(int i) => i % width;
  int yOf(int i) => i ~/ width;
  int index(int x, int y) => y * width + x;

  Tile at(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return Tile.wall;
    return tiles[y * width + x];
  }

  Tile tileAt(int i) => i < 0 ? Tile.wall : tiles[i];

  /// Neighbour index in direction [d], or -1 when off the grid. Through the
  /// side tunnel the neighbour is on the opposite edge.
  int neighbor(int i, Dir d) {
    if (d == Dir.none) return i;
    var x = i % width + d.dx;
    final y = i ~/ width + d.dy;
    if (y < 0 || y >= height) return -1;
    if (x < 0 || x >= width) {
      if (!isTunnelRow(y)) return -1;
      x = (x + width) % width;
    }
    return y * width + x;
  }

  /// Both edges of row [y] are open.
  bool isTunnelRow(int y) =>
      tiles[y * width] != Tile.wall &&
      tiles[y * width + width - 1] != Tile.wall;

  /// Tiles of the side tunnel, from each edge up to the first junction.
  late final Set<int> tunnelTiles = _findTunnel();

  Set<int> _findTunnel() {
    final out = <int>{};
    for (var y = 1; y < height - 1; y++) {
      if (!isTunnelRow(y)) continue;
      bool plain(int x) =>
          !isWallXY(x, y) && isWallXY(x, y - 1) && isWallXY(x, y + 1);
      for (var x = 0; x < width && plain(x); x++) {
        out.add(index(x, y));
      }
      for (var x = width - 1; x >= 0 && plain(x); x--) {
        out.add(index(x, y));
      }
    }
    return out;
  }

  bool isTunnel(int i) => tunnelTiles.contains(i);

  /// World x wrapped into [0, width).
  double wrapX(double x) => x < 0 ? x + width : (x >= width ? x - width : x);

  /// Shortest horizontal offset, counting the way through the edge.
  double wrapDx(double dx) {
    if (dx > width / 2) return dx - width;
    if (dx < -width / 2) return dx + width;
    return dx;
  }

  /// Pac-Man (and the player ghost) stay in the corridors.
  bool pacWalkable(int i) {
    final t = tileAt(i);
    return t == Tile.empty || t == Tile.pellet || t == Tile.power;
  }

  /// AI ghosts may also use the door and the house.
  bool ghostWalkable(int i) => tileAt(i) != Tile.wall;

  bool isWallXY(int x, int y) => at(x, y) == Tile.wall;

  /// Breadth-first path distances from [from]; -1 = unreachable.
  List<int> distancesFrom(int from, bool Function(int) passable) {
    final dist = List<int>.filled(tiles.length, -1);
    if (from < 0) return dist;
    dist[from] = 0;
    final queue = Queue<int>()..add(from);
    while (queue.isNotEmpty) {
      final c = queue.removeFirst();
      final nd = dist[c] + 1;
      for (final d in moveDirs) {
        final n = neighbor(c, d);
        if (n >= 0 && dist[n] < 0 && passable(n)) {
          dist[n] = nd;
          queue.add(n);
        }
      }
    }
    return dist;
  }

  /// First step on a shortest path from [from] to [to].
  Dir stepToward(int from, int to, bool Function(int) passable) {
    if (from == to) return Dir.none;
    final dist = distancesFrom(to, passable);
    var best = Dir.none;
    var bestD = 1 << 30;
    for (final d in moveDirs) {
      final n = neighbor(from, d);
      if (n < 0 || dist[n] < 0) continue;
      if (dist[n] < bestD) {
        bestD = dist[n];
        best = d;
      }
    }
    return best;
  }
}
