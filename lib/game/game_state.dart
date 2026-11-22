import 'dart:math' as math;
import 'dart:ui' show Color;

import 'entities.dart';
import 'maze.dart';
import 'pacman_ai.dart';

enum Difficulty { easy, hard, hell }

enum Phase { ready, playing, caught, won, lost }

enum Turn { none, left, right }

enum EventType { pellet, power, ghostEaten, playerEaten, pacCaught, won, lost }

class GameEvent {
  const GameEvent(this.type, {this.tile = -1, this.byPlayer = false});
  final EventType type;
  final int tile;
  final bool byPlayer;
}

/// Pure game logic: no Flutter widgets, fully testable.
class GameState {
  GameState({required this.difficulty, this.level = 1, int? seed})
    : rng = math.Random(seed),
      maze = Maze.classic() {
    brain = PacmanAI(rng);
    pac = PacMan(maze.pacStart, pacSpeed);
    player = Ghost(
      tile: maze.playerStart,
      personality: Personality.inky,
      isPlayer: true,
      color: const Color(0xFF00E5FF),
      speed: playerSpeed,
    );
    aiGhosts = [
      Ghost(
        tile: maze.ghostStarts[0],
        personality: Personality.blinky,
        isPlayer: false,
        color: const Color(0xFFFF2020),
        speed: aiSpeed,
        releaseDelay: 0.5,
      ),
      Ghost(
        tile: maze.ghostStarts[1],
        personality: Personality.pinky,
        isPlayer: false,
        color: const Color(0xFFFFB8DE),
        speed: aiSpeed,
        releaseDelay: 4,
      ),
      Ghost(
        tile: maze.ghostStarts[2],
        personality: Personality.clyde,
        isPlayer: false,
        color: const Color(0xFFFFB851),
        speed: aiSpeed,
        releaseDelay: 8,
      ),
    ];
    ghosts = [player, ...aiGhosts];
    _resetPositions();
    phase = Phase.ready;
    phaseTimer = 2.0;
  }

  final Difficulty difficulty;
  final int level;
  final math.Random rng;
  final Maze maze;
  late final PacmanAI brain;
  late final PacMan pac;
  late final Ghost player;
  late final List<Ghost> aiGhosts;
  late final List<Ghost> ghosts;

  Phase phase = Phase.ready;
  double phaseTimer = 0;
  double time = 0; // game time (only runs while playing)
  double clock = 0; // wall clock for animations
  int pacLives = 3;
  int playerCatches = 0;
  int teamCatches = 0;
  double frightTimer = 0;

  // Scatter/chase schedule of the arcade ghosts (seconds).
  static const _modeSchedule = [7.0, 20.0, 7.0, 20.0, 5.0, 20.0, 5.0];
  int _modeIndex = 0;
  double _modeTimer = _modeSchedule[0];
  bool get scatter => _modeIndex.isEven && _modeIndex < _modeSchedule.length;

  // Heartbeat of Pac-Man's light beam: excitement rises while it eats.
  double excitement = 0.2;
  double _beatPhase = 0;

  // Player input.
  Dir wantedDir = Dir.none; // absolute (top-down view)
  Turn queuedTurn = Turn.none; // relative (first-person view)

  final List<GameEvent> _events = [];

  // ---------------------------------------------------------------- tuning
  bool get firstPerson => difficulty != Difficulty.easy;
  bool get showBeam => difficulty == Difficulty.hard;
  bool get proximitySound => difficulty == Difficulty.hard;
  bool get minimapShowsTrail => difficulty == Difficulty.hard;

  double get pacSpeed => math.min(6.2, 4.6 + 0.3 * (level - 1));
  double get playerSpeed => 5.0;
  double get aiSpeed => math.min(5.0, 4.0 + 0.2 * (level - 1));
  double get frightDuration => math.max(2.0, 7.0 - (level - 1));

  /// 0 = clueless, 1 = sharp. Grows with difficulty, level and as the
  /// level progresses (fewer pellets left = more desperate & careful).
  double get smartness {
    final base = switch (difficulty) {
      Difficulty.easy => 0.3,
      Difficulty.hard => 0.5,
      Difficulty.hell => 0.6,
    };
    final progress = 1 - maze.pelletsLeft / maze.totalPellets;
    return (base + 0.12 * (level - 1) + 0.25 * progress).clamp(0.0, 1.0);
  }

  /// Current beam brightness 0..1, beating like a heart.
  double get beatIntensity {
    final p = _beatPhase % 1.0;
    double bump(double c, double w) =>
        math.exp(-((p - c) * (p - c)) / (2 * w * w));
    final wave = math.min(1.0, bump(0.05, 0.035) + 0.6 * bump(0.22, 0.04));
    return (0.12 + (0.25 + 0.75 * excitement) * wave).clamp(0.0, 1.0);
  }

  double get heartRateBpm => 50 + 110 * excitement;

  List<GameEvent> drainEvents() {
    final out = List<GameEvent>.of(_events);
    _events.clear();
    return out;
  }

  // ----------------------------------------------------------------- input
  void inputDir(Dir d) {
    wantedDir = d;
    if (player.state == GhostState.active && d == player.dir.opposite) {
      player.reverse(maze);
    }
  }

  void inputTurn(Turn t) => queuedTurn = t;

  void inputBack() {
    if (player.state != GhostState.active) return;
    player.reverse(maze);
    queuedTurn = Turn.none;
  }

  // ---------------------------------------------------------------- update
  void update(double dt) {
    dt = dt.clamp(0.0, 0.1);
    clock += dt;
    _beatPhase += dt * heartRateBpm / 60;
    excitement = math.max(0.0, excitement - dt * 0.06);
    if (!pac.stopped && phase == Phase.playing) pac.mouth += dt * 20;

    switch (phase) {
      case Phase.ready:
        phaseTimer -= dt;
        if (phaseTimer <= 0) phase = Phase.playing;
        return;
      case Phase.caught:
        phaseTimer -= dt;
        if (phaseTimer <= 0) {
          _resetPositions();
          phase = Phase.ready;
          phaseTimer = 1.5;
        }
        return;
      case Phase.won:
      case Phase.lost:
        return;
      case Phase.playing:
        break;
    }

    // Sub-step so fast movers never tunnel through each other.
    var left = dt;
    while (left > 0 && phase == Phase.playing) {
      final h = math.min(left, 1 / 120);
      left -= h;
      _tick(h);
    }
  }

  void _tick(double dt) {
    time += dt;
    if (frightTimer > 0) {
      frightTimer -= dt;
      if (frightTimer <= 0) {
        frightTimer = 0;
        for (final g in ghosts) {
          g.frightened = false;
        }
      }
    } else if (_modeIndex < _modeSchedule.length) {
      _modeTimer -= dt;
      if (_modeTimer <= 0) {
        _modeIndex++;
        if (_modeIndex < _modeSchedule.length) {
          _modeTimer = _modeSchedule[_modeIndex];
        }
        for (final g in aiGhosts) {
          if (g.state == GhostState.active && !g.frightened) g.reverse(maze);
        }
      }
    }

    pac.speed = pacSpeed * (frightTimer > 0 ? 1.1 : 1.0);
    pac.step(
      dt,
      maze,
      maze.pacWalkable,
      () => brain.decide(this),
      onArrive: _pacArrive,
    );
    if (phase != Phase.playing) return;

    for (final g in ghosts) {
      _updateGhost(g, dt);
    }
    _checkCollisions();
  }

  void _pacArrive(int t) {
    final tile = maze.tiles[t];
    if (tile != Tile.pellet && tile != Tile.power) return;
    maze.tiles[t] = Tile.empty;
    maze.pelletsLeft--;
    if (tile == Tile.power) {
      excitement = 1;
      frightTimer = frightDuration;
      for (final g in ghosts) {
        if (g.state == GhostState.active || g.state == GhostState.leaving) {
          g.frightened = true;
          if (!g.isPlayer && g.state == GhostState.active) g.reverse(maze);
        }
      }
      _events.add(GameEvent(EventType.power, tile: t));
    } else {
      excitement = math.min(1.0, excitement + 0.06);
      _events.add(GameEvent(EventType.pellet, tile: t));
    }
    if (maze.pelletsLeft <= 0) {
      phase = Phase.lost;
      _events.add(const GameEvent(EventType.lost));
    }
  }

  void _updateGhost(Ghost g, double dt) {
    switch (g.state) {
      case GhostState.inHouse:
        g.timer -= dt;
        if (g.timer <= 0) g.state = GhostState.leaving;
      case GhostState.leaving:
        g.speed = aiSpeed * 0.6;
        g.step(dt, maze, maze.ghostWalkable, () {
          if (g.tile == maze.houseExit) {
            g.state = GhostState.active;
            return maze.pacWalkable(maze.neighbor(g.tile, Dir.left))
                ? Dir.left
                : Dir.right;
          }
          return maze.stepToward(g.tile, maze.houseExit, maze.ghostWalkable);
        });
      case GhostState.eaten:
        if (g.isPlayer) {
          g.timer -= dt;
          if (g.timer <= 0) {
            g.placeAt(maze.playerStart, Dir.left);
            g.state = GhostState.active;
            g.frightened = false;
            queuedTurn = Turn.none;
            wantedDir = Dir.none;
          }
          return;
        }
        g.speed = 9;
        g.step(dt, maze, maze.ghostWalkable, () {
          if (g.tile == maze.houseCenter) {
            g.state = GhostState.inHouse;
            g.timer = 1.0;
            g.frightened = false;
            return Dir.none;
          }
          return maze.stepToward(g.tile, maze.houseCenter, maze.ghostWalkable);
        });
      case GhostState.active:
        if (g.isPlayer) {
          g.speed = g.frightened ? 3.6 : playerSpeed;
          g.step(dt, maze, maze.pacWalkable, _decidePlayer);
        } else {
          g.speed = g.frightened ? 2.6 : aiSpeed;
          g.step(dt, maze, maze.pacWalkable, () => _decideAi(g));
        }
    }
  }

  Dir _decidePlayer() {
    final g = player;
    bool can(Dir d) => maze.pacWalkable(maze.neighbor(g.tile, d));
    if (!firstPerson) {
      if (wantedDir != Dir.none && can(wantedDir)) return wantedDir;
      return can(g.dir) ? g.dir : Dir.none;
    }
    if (queuedTurn != Turn.none) {
      final d = queuedTurn == Turn.left ? g.dir.turnLeft : g.dir.turnRight;
      if (can(d)) {
        queuedTurn = Turn.none;
        return d;
      }
    }
    if (can(g.dir)) return g.dir;
    final sides = [g.dir.turnLeft, g.dir.turnRight].where(can).toList();
    if (sides.length == 1) return sides.first; // follow the bend
    if (sides.isEmpty) return g.dir.opposite; // dead end
    return Dir.none; // T-junction: wait for the player to choose
  }

  Dir _decideAi(Ghost g) {
    final opts = [
      for (final d in moveDirs)
        if (d != g.dir.opposite && maze.pacWalkable(maze.neighbor(g.tile, d)))
          d,
    ];
    if (opts.isEmpty) return g.dir.opposite;
    if (g.frightened) return opts[rng.nextInt(opts.length)];
    final (tx, ty) = _targetFor(g);
    final gx = maze.xOf(g.tile), gy = maze.yOf(g.tile);
    var best = opts.first;
    var bestD = double.infinity;
    for (final d in opts) {
      final dx = gx + d.dx - tx, dy = gy + d.dy - ty;
      final dist = (dx * dx + dy * dy).toDouble();
      if (dist < bestD) {
        bestD = dist;
        best = d;
      }
    }
    return best;
  }

  (int, int) _targetFor(Ghost g) {
    final px = maze.xOf(pac.tile), py = maze.yOf(pac.tile);
    final corner = switch (g.personality) {
      Personality.blinky => (maze.width - 3, -3),
      Personality.pinky => (2, -3),
      Personality.clyde => (0, maze.height + 1),
      Personality.inky => (maze.width - 1, maze.height + 1),
    };
    if (scatter) return corner;
    switch (g.personality) {
      case Personality.pinky:
        return (px + 4 * pac.dir.dx, py + 4 * pac.dir.dy);
      case Personality.clyde:
        final gx = maze.xOf(g.tile), gy = maze.yOf(g.tile);
        final d2 = (gx - px) * (gx - px) + (gy - py) * (gy - py);
        return d2 > 64 ? (px, py) : corner;
      default:
        return (px, py);
    }
  }

  void _checkCollisions() {
    final px = pac.x(maze), py = pac.y(maze);
    for (final g in ghosts) {
      if (g.state == GhostState.eaten || g.state == GhostState.inHouse) {
        continue;
      }
      final dx = g.x(maze) - px, dy = g.y(maze) - py;
      if (dx * dx + dy * dy > 0.36) continue;
      if (g.frightened) {
        g.state = GhostState.eaten;
        g.frightened = false;
        g.timer = 3;
        _events.add(
          GameEvent(g.isPlayer ? EventType.playerEaten : EventType.ghostEaten),
        );
      } else {
        pacLives--;
        teamCatches++;
        if (g.isPlayer) playerCatches++;
        _events.add(GameEvent(EventType.pacCaught, byPlayer: g.isPlayer));
        if (pacLives <= 0) {
          phase = Phase.won;
          _events.add(const GameEvent(EventType.won));
        } else {
          phase = Phase.caught;
          phaseTimer = 1.6;
        }
        return;
      }
    }
  }

  void _resetPositions() {
    pac.placeAt(maze.pacStart, Dir.left);
    pac.speed = pacSpeed;
    player.placeAt(maze.playerStart, Dir.left);
    player.state = GhostState.active;
    player.frightened = false;
    for (final g in aiGhosts) {
      g.placeAt(g.spawnTile, Dir.up);
      g.state = GhostState.inHouse;
      g.frightened = false;
      g.timer = g.releaseDelay;
    }
    frightTimer = 0;
    queuedTurn = Turn.none;
    wantedDir = Dir.none;
  }
}
