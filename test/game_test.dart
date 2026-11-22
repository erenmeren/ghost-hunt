import 'package:flutter_test/flutter_test.dart';
import 'package:ghost_hunt/game/entities.dart';
import 'package:ghost_hunt/game/game_state.dart';
import 'package:ghost_hunt/game/maze.dart';

void main() {
  group('Maze', () {
    test('classic layout parses with 244 pellets', () {
      final m = Maze.classic();
      expect(m.width, 28);
      expect(m.height, 31);
      expect(m.totalPellets, 244);
      expect(m.ghostStarts.length, 3);
    });

    test('every pellet is reachable by Pac-Man', () {
      final m = Maze.classic();
      final d = m.distancesFrom(m.pacStart, m.pacWalkable);
      for (var i = 0; i < m.tiles.length; i++) {
        if (m.tiles[i] == Tile.pellet || m.tiles[i] == Tile.power) {
          expect(d[i], greaterThanOrEqualTo(0), reason: 'pellet $i');
        }
      }
    });

    test('ghost house exits to the player spawn', () {
      final m = Maze.classic();
      for (final g in m.ghostStarts) {
        expect(
          m.distancesFrom(g, m.ghostWalkable)[m.houseExit],
          greaterThan(0),
        );
        expect(m.pacWalkable(g), isFalse);
      }
    });

    test('turning helpers', () {
      expect(Dir.up.turnLeft, Dir.left);
      expect(Dir.up.turnRight, Dir.right);
      expect(Dir.right.turnLeft, Dir.up);
      expect(Dir.left.opposite, Dir.right);
    });
  });

  group('Pac-Man AI', () {
    test('clears the level alone when no ghost ever leaves home', () {
      final s = GameState(difficulty: Difficulty.easy, seed: 1);
      // Park the player ghost far away and keep the AI ghosts locked in.
      for (final g in s.aiGhosts) {
        g.releaseDelay = 1e9;
      }
      for (final g in s.aiGhosts) {
        g.timer = 1e9;
      }
      s.player.state = GhostState.eaten;
      s.player.timer = 1e9;
      var t = 0.0;
      while (s.phase != Phase.lost && t < 300) {
        s.update(1 / 30);
        t += 1 / 30;
      }
      expect(s.phase, Phase.lost, reason: 'pellets left ${s.maze.pelletsLeft}');
      expect(t, lessThan(150));
    });

    test('runs away from a ghost coming straight at it', () {
      final s = GameState(difficulty: Difficulty.hard, seed: 2);
      final m = s.maze;
      // Bottom corridor (y=29): Pac-Man at x=10 heading left, player ghost
      // at x=6 heading right towards it.
      s.pac.placeAt(m.index(10, 29), Dir.left);
      s.player.placeAt(m.index(6, 29), Dir.right);
      s.phase = Phase.playing;
      s.brain.carelessness = 0;
      final d = s.brain.decide(s);
      expect(d, Dir.right);
    });

    test('random full games finish without errors', () {
      final outcomes = <Phase>[];
      for (var seed = 0; seed < 12; seed++) {
        final s = GameState(
          difficulty: Difficulty.values[seed % 3],
          seed: seed,
          level: 1,
        );
        // Simple chaser bot for the player ghost.
        var t = 0.0;
        while ((s.phase != Phase.won && s.phase != Phase.lost) && t < 400) {
          if (s.player.progress == 0) {
            final d = s.maze.stepToward(
              s.player.tile,
              s.pac.nearTile(s.maze),
              s.maze.pacWalkable,
            );
            if (s.firstPerson) {
              if (d == s.player.dir.turnLeft) s.inputTurn(Turn.left);
              if (d == s.player.dir.turnRight) s.inputTurn(Turn.right);
              if (d == s.player.dir.opposite) s.inputBack();
            } else {
              s.inputDir(d);
            }
          }
          s.update(1 / 60);
          t += 1 / 60;
          s.drainEvents();
        }
        outcomes.add(s.phase);
      }
      // ignore: avoid_print
      print('outcomes: $outcomes');
      expect(outcomes.where((p) => p == Phase.won), isNotEmpty);
    });
  });
}
