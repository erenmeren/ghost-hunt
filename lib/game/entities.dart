import 'dart:math' as math;
import 'dart:ui' show Color;

import 'maze.dart';

/// Something that moves tile-to-tile through the maze.
///
/// It sits on [tile] and is [progress] (0..1) of the way towards the
/// neighbouring tile in [dir]. Decisions are only taken on tile centres.
class Mover {
  Mover(this.tile, this.dir, this.speed);

  int tile;
  Dir dir;
  double progress = 0;
  double speed; // tiles per second
  bool stopped = false;

  double x(Maze m) => m.wrapX(m.xOf(tile) + 0.5 + dir.dx * progress);
  double y(Maze m) => m.yOf(tile) + 0.5 + dir.dy * progress;

  /// The tile whose centre is closest to the mover.
  int nearTile(Maze m) {
    if (progress < 0.5) return tile;
    final n = m.neighbor(tile, dir);
    return n < 0 ? tile : n;
  }

  void placeAt(int t, Dir d) {
    tile = t;
    dir = d;
    progress = 0;
    stopped = false;
  }

  /// Turn around mid-corridor (allowed for Pac-Man and the player).
  void reverse(Maze m) {
    if (progress > 0) {
      final n = m.neighbor(tile, dir);
      if (n >= 0) {
        tile = n;
        progress = 1 - progress;
      }
    }
    dir = dir.opposite;
    stopped = false;
  }

  /// Advance by `speed * dt`. [decide] is asked for a direction on every
  /// tile centre; [onArrive] fires whenever a new tile centre is reached.
  void step(
    double dt,
    Maze m,
    bool Function(int) passable,
    Dir Function() decide, {
    void Function(int tile)? onArrive,
  }) {
    var dist = speed * dt;
    var guard = 0;
    while (dist > 1e-9 && guard++ < 6) {
      if (progress == 0) {
        final d = decide();
        if (d == Dir.none || !passable(m.neighbor(tile, d))) {
          if (d != Dir.none) dir = d;
          stopped = true;
          return;
        }
        dir = d;
        stopped = false;
      }
      final need = 1 - progress;
      if (dist < need) {
        progress += dist;
        return;
      }
      dist -= need;
      tile = m.neighbor(tile, dir);
      progress = 0;
      onArrive?.call(tile);
    }
  }
}

enum Personality { blinky, pinky, inky, clyde }

enum GhostState { inHouse, leaving, active, eaten }

class Ghost extends Mover {
  Ghost({
    required int tile,
    required this.personality,
    required this.isPlayer,
    required this.color,
    required double speed,
    this.releaseDelay = 0,
  }) : spawnTile = tile,
       super(tile, Dir.left, speed);

  final Personality personality;
  final bool isPlayer;
  final Color color;
  final int spawnTile;
  double releaseDelay;
  GhostState state = GhostState.inHouse;
  bool frightened = false;
  double timer = 0; // release / respawn countdown

  bool get dangerous => !frightened && state != GhostState.eaten;
  bool get visible => !(isPlayer && state == GhostState.eaten);
}

class PacMan extends Mover {
  PacMan(int tile, double speed) : super(tile, Dir.left, speed);

  double mouth = 0; // animation phase

  double get mouthOpen => (math.sin(mouth) * 0.5 + 0.5);
}
