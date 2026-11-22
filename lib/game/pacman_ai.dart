import 'dart:math' as math;

import 'entities.dart';
import 'game_state.dart';
import 'maze.dart';

/// Pac-Man's brain: eat pellets, keep away from ghosts, grab power pellets
/// when cornered and hunt frightened ghosts. [GameState.smartness] (0..1)
/// controls how far it looks and how often it gets careless.
class PacmanAI {
  PacmanAI(this.rng);

  final math.Random rng;
  double _distractedUntil = -1;

  /// Chance per decision (scaled by 1 - smartness) to ignore ghosts briefly.
  double carelessness = 0.04;

  Dir decide(GameState s) {
    final m = s.maze;
    final pac = s.pac;
    final here = pac.tile;
    final smart = s.smartness;

    final options = <Dir>[
      for (final d in moveDirs)
        if (m.pacWalkable(m.neighbor(here, d))) d,
    ];
    if (options.isEmpty) return Dir.none;

    // --- Who is dangerous and how close (by path, not straight line)?
    final perceive = 4 + smart * 14;
    final threats = <List<int>>[];
    var nearest = 1 << 20;
    for (final g in s.ghosts) {
      if (!g.dangerous || g.state == GhostState.inHouse) continue;
      if (g.isPlayer && s.invisible) continue; // can't see you
      final dist = m.distancesFrom(g.nearTile(m), m.ghostWalkable);
      final d = dist[here];
      if (d < 0 || d > perceive) continue;
      threats.add(dist);
      nearest = math.min(nearest, d);
    }

    // --- Occasional carelessness, rarer the smarter Pac-Man gets.
    if (s.time >= _distractedUntil &&
        rng.nextDouble() < (1 - smart) * carelessness) {
      _distractedUntil = s.time + 0.5 + rng.nextDouble() * 0.8;
    }
    if (s.time < _distractedUntil) threats.clear();

    final prey = [
      for (final g in s.ghosts)
        if (g.frightened && g.state == GhostState.active) g,
    ];
    final margin = smart > 0.6 ? 1 : 0;
    final danger = threats.isEmpty
        ? 0.0
        : ((10 - nearest) / 10).clamp(0.0, 1.0).toDouble();

    var best = -double.infinity;
    var bestDir = options.first;
    for (final d in options) {
      final n = m.neighbor(here, d);
      // Commit to this direction: the tile we leave is closed behind us, so
      // the area counted is what this corridor really leads to.
      final dp = m.distancesFrom(n, (i) => i != here && m.pacWalkable(i));

      var pelletD = 60;
      var powerD = 1 << 20;
      var safeArea = 0;
      for (var t = 0; t < dp.length; t++) {
        final pd = dp[t];
        if (pd < 0) continue;
        var safe = true;
        if (threats.isNotEmpty) {
          var dmin = 1 << 20;
          for (final th in threats) {
            final gd = th[t];
            if (gd >= 0 && gd < dmin) dmin = gd;
          }
          safe = dmin > pd + 1 + margin;
          if (safe && pd <= 20) safeArea++;
        }
        final tile = m.tiles[t];
        if (safe && (tile == Tile.pellet || tile == Tile.power)) {
          if (pd < pelletD) pelletD = pd;
          if (tile == Tile.power && pd < powerD) powerD = pd;
        }
      }

      var score = -pelletD.toDouble();
      if (threats.isNotEmpty) {
        score =
            -pelletD * (1 - 0.6 * danger) +
            safeArea * (0.15 + 0.6 * smart) * danger;
        if (smart > 0.35 && powerD < 12) {
          score += (12 - powerD) * danger * 1.5;
        }
        var dn = 1 << 20;
        for (final th in threats) {
          if (th[n] >= 0 && th[n] < dn) dn = th[n];
        }
        if (dn <= 1) {
          score -= 500;
        } else if (dn == 2) {
          score -= 40 * smart;
        }
      }

      if (smart > 0.25 && s.frightTimer > 0.5) {
        for (final g in prey) {
          final dg = dp[g.nearTile(m)];
          if (dg < 0) continue;
          if ((dg + 1) / pac.speed < s.frightTimer - 0.3) {
            score += math.max(0, 25 - dg) * 1.2;
          }
        }
      }

      if (d == pac.dir.opposite) score -= 0.6;
      if (d == pac.dir) score += 0.1;
      if (score > best) {
        best = score;
        bestDir = d;
      }
    }
    return bestDir;
  }
}
