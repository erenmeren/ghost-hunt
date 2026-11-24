import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghost_hunt/game/entities.dart';
import 'package:ghost_hunt/game/fruit.dart';
import 'package:ghost_hunt/game/game_state.dart';
import 'package:ghost_hunt/game/maze.dart';
import 'package:ghost_hunt/ui/minimap_painter.dart';
import 'package:ghost_hunt/ui/wall_art.dart';

const tunnelRow = 12;

/// Playing, with every ghost out of the way.
GameState quiet({Difficulty d = Difficulty.easy, int level = 1}) {
  final s = GameState(difficulty: d, seed: 1, level: level);
  s.phase = Phase.playing;
  s.brain.carelessness = 0;
  for (final g in s.aiGhosts) {
    g.timer = 1e9;
  }
  s.player
    ..state = GhostState.eaten
    ..timer = 1e9;
  return s;
}

/// Clears pellets from the top until [eaten] are gone.
void eatDownTo(GameState s, int eaten) {
  final m = s.maze;
  for (var i = 0; i < m.tiles.length && m.pelletsEaten < eaten; i++) {
    if (m.tiles[i] == Tile.pellet) {
      m.tiles[i] = Tile.empty;
      m.pelletsLeft--;
    }
  }
}

/// Runs until Pac-Man has eaten one more pellet.
void eatOnePellet(GameState s) {
  final before = s.maze.pelletsLeft;
  for (var i = 0; i < 100 && s.maze.pelletsLeft == before; i++) {
    s.update(0.01);
  }
  expect(s.maze.pelletsLeft, before - 1);
}

void main() {
  group('Maze', () {
    test('has 240 pellets and 4 power pellets', () {
      final m = Maze.classic();
      expect(m.tiles.where((t) => t == Tile.pellet).length, 240);
      expect(m.tiles.where((t) => t == Tile.power).length, 4);
    });

    test('is mirrored, has no dead ends and one side tunnel', () {
      final m = Maze.classic();
      for (var i = 0; i < m.tiles.length; i++) {
        final x = m.xOf(i), y = m.yOf(i);
        expect(m.isWallXY(x, y), m.isWallXY(m.width - 1 - x, y));
        if (!m.pacWalkable(i)) continue;
        final exits = moveDirs.where((d) => m.pacWalkable(m.neighbor(i, d)));
        expect(exits.length, greaterThanOrEqualTo(2), reason: '($x,$y)');
      }
      final open = [
        for (var y = 0; y < m.height; y++)
          if (m.isTunnelRow(y)) y,
      ];
      expect(open, [tunnelRow]);
      expect(m.isTunnel(m.index(0, tunnelRow)), isTrue);
      expect(m.isTunnel(m.index(27, tunnelRow)), isTrue);
      expect(m.isTunnel(m.fruitTile), isFalse);
      expect(m.isTunnel(m.index(5, 29)), isFalse);
    });

    test('paths go through the tunnel, closed edges do not wrap', () {
      final m = Maze.classic();
      final a = m.index(0, tunnelRow), b = m.index(27, tunnelRow);
      expect(m.distancesFrom(a, m.pacWalkable)[b], 1);
      expect(m.stepToward(a, b, m.pacWalkable), Dir.left);
      expect(m.neighbor(m.index(0, 5), Dir.left), -1);
    });

    test('wall outlines stay inside the field', () {
      final b = WallArt.of(Maze.classic()).walls.getBounds();
      expect(const ui.Rect.fromLTWH(0, 0, 28, 31).contains(b.topLeft), isTrue);
      expect(b.right, lessThan(28));
      expect(b.bottom, lessThan(31));
    });
  });

  test('border is a double line, islands are single outlines', () {
    final m = Maze.classic();
    // Islands = wall masses that do not touch the rim of the field.
    final seen = <int>{};
    var islands = 0;
    for (var i = 0; i < m.tiles.length; i++) {
      if (m.tiles[i] != Tile.wall || seen.contains(i)) continue;
      var touchesRim = false;
      final todo = [i];
      while (todo.isNotEmpty) {
        final t = todo.removeLast();
        if (!seen.add(t)) continue;
        final x = m.xOf(t), y = m.yOf(t);
        if (x == 0 || y == 0 || x == 27 || y == 30) touchesRim = true;
        for (final d in moveDirs) {
          final nx = x + d.dx, ny = y + d.dy;
          if (nx >= 0 && ny >= 0 && nx < 28 && ny < 31 && m.isWallXY(nx, ny)) {
            todo.add(m.index(nx, ny));
          }
        }
      }
      if (!touchesRim) islands++;
    }
    expect(islands, greaterThan(20));
    final lines = WallArt.of(m).walls.computeMetrics().toList();
    expect(lines.where((l) => l.isClosed).length, islands);
    // Two border halves (the tunnel cuts it), two lines each.
    expect(lines.where((l) => !l.isClosed).length, 4);
  });

  group('Tunnel', () {
    test('Pac-Man wraps around', () {
      final s = quiet();
      final m = s.maze;
      // Nothing to eat on this side but one pellet across the edge.
      for (var i = 0; i < m.tiles.length; i++) {
        if (m.tiles[i] == Tile.pellet || m.tiles[i] == Tile.power) {
          m.tiles[i] = Tile.empty;
        }
      }
      m.tiles[m.index(23, tunnelRow)] = Tile.pellet;
      m.pelletsLeft = 2;
      s.pac.placeAt(m.index(1, tunnelRow), Dir.left);
      for (var i = 0; i < 60; i++) {
        s.update(0.01);
        expect(s.pac.x(m), inInclusiveRange(0, m.width));
      }
      expect(m.xOf(s.pac.tile), greaterThan(20));
      expect(m.yOf(s.pac.tile), tunnelRow);
    });

    test('the player ghost wraps around, both ways', () {
      for (final d in [Dir.left, Dir.right]) {
        final s = quiet();
        final m = s.maze;
        final from = d == Dir.left ? 1 : 26;
        s.player
          ..state = GhostState.active
          ..placeAt(m.index(from, tunnelRow), d);
        s.inputDir(d);
        for (var i = 0; i < 100; i++) {
          s.update(0.01);
        }
        final x = m.xOf(s.player.tile);
        expect(x, d == Dir.left ? greaterThan(20) : lessThan(8));
        expect(m.yOf(s.player.tile), tunnelRow);
      }
    });

    test('an AI ghost wraps around', () {
      final s = quiet();
      final m = s.maze;
      final g = s.aiGhosts[0]
        ..state = GhostState.active
        ..placeAt(m.index(1, tunnelRow), Dir.left);
      for (var i = 0; i < 120; i++) {
        s.update(0.01);
      }
      expect(m.xOf(g.tile), greaterThan(20));
    });

    test('ghosts are slow inside, Pac-Man is not', () {
      final s = quiet();
      final m = s.maze;
      final g = s.aiGhosts[0]..state = GhostState.active;
      s.player.state = GhostState.active;
      g.placeAt(m.index(2, tunnelRow), Dir.left);
      s.player.placeAt(m.index(25, tunnelRow), Dir.right);
      s.inputDir(Dir.right);
      s.pac.placeAt(m.index(13, 29), Dir.left);
      s.update(0.01);
      expect(g.speed, closeTo(s.aiSpeed * 0.5, 1e-9));
      expect(s.player.speed, closeTo(s.playerSpeed * 0.5, 1e-9));

      s.pac.placeAt(m.index(2, tunnelRow), Dir.left);
      g.placeAt(m.index(5, 29), Dir.left);
      s.player.placeAt(m.index(20, 29), Dir.right);
      s.update(0.01);
      expect(g.speed, closeTo(s.aiSpeed, 1e-9));
      expect(s.player.speed, closeTo(s.playerSpeed, 1e-9));
      expect(s.pac.speed, closeTo(s.pacSpeed, 1e-9));
    });

    test('a frightened ghost never gets faster in the tunnel', () {
      final s = quiet();
      final m = s.maze;
      s.frightTimer = 5;
      final g = s.aiGhosts[0]
        ..state = GhostState.active
        ..frightened = true
        ..placeAt(m.index(2, tunnelRow), Dir.left);
      s.update(0.01);
      expect(g.speed, lessThanOrEqualTo(s.aiSpeed * 0.5));
    });

    test('ghosts meet him across the edge', () {
      final s = quiet();
      final m = s.maze;
      s.player
        ..state = GhostState.active
        ..placeAt(m.index(27, tunnelRow), Dir.right)
        ..progress = 0.4;
      s.pac
        ..placeAt(m.index(0, tunnelRow), Dir.left)
        ..progress = 0.3;
      s.update(0.01);
      expect(s.pacLives, 2);
    });
  });

  group('Fruit', () {
    test('appears at 70 and at 170 pellets', () {
      final s = quiet();
      for (final n in [70, 170]) {
        eatDownTo(s, n - 2);
        s.pac.placeAt(s.maze.index(n == 70 ? 14 : 20, 29), Dir.left);
        eatOnePellet(s);
        expect(s.fruit, isNull, reason: '${n - 1} eaten');
        eatOnePellet(s);
        expect(s.maze.pelletsEaten, n);
        expect(s.fruit, isNotNull, reason: '$n eaten');
        expect(s.fruit!.tile, s.maze.fruitTile);
        s.fruit = null;
      }
    });

    test('disappears after its time', () {
      final s = quiet();
      s.pac.placeAt(s.maze.index(13, 29), Dir.left);
      s.fruit = Fruit(FruitType.cherry, s.maze.fruitTile, 0.5);
      // Pac-Man cannot get there in half a second.
      for (var i = 0; i < 45; i++) {
        s.update(0.01);
      }
      expect(s.fruit, isNotNull);
      for (var i = 0; i < 10; i++) {
        s.update(0.01);
      }
      expect(s.fruit, isNull);
      expect(s.eatenFruit, isEmpty);
      expect(GameState.fruitSeconds, inInclusiveRange(9, 10));
    });

    test('ghosts on the fruit tile do not eat it', () {
      final s = quiet();
      final m = s.maze;
      s.pac.placeAt(m.index(13, 29), Dir.left);
      s.fruit = Fruit(FruitType.cherry, m.fruitTile, 9.5);
      s.player
        ..state = GhostState.active
        ..placeAt(m.fruitTile, Dir.left);
      s.aiGhosts[0]
        ..state = GhostState.active
        ..placeAt(m.fruitTile, Dir.right);
      for (var i = 0; i < 20; i++) {
        s.update(0.01);
      }
      expect(s.fruit, isNotNull);
      expect(s.eatenFruit, isEmpty);
      expect(s.boostTimer, 0);
    });

    test('Pac-Man eats it: boost and fruit list', () {
      final s = quiet();
      final m = s.maze;
      s.fruit = Fruit(FruitType.cherry, m.fruitTile, 9.5);
      s.pac.placeAt(m.fruitTile, Dir.left);
      s.update(0.01);
      expect(s.fruit, isNull);
      expect(s.eatenFruit, [FruitType.cherry]);
      s.update(0.01);
      expect(s.pac.speed, closeTo(s.pacSpeed * 1.25, 1e-9));
      for (var i = 0; i < 310; i++) {
        s.update(0.01);
      }
      expect(s.boostTimer, 0);
      expect(s.pac.speed, closeTo(s.pacSpeed, 1e-9));
      expect(s.eatenFruit, [FruitType.cherry]);
    });

    test('Pac-Man goes for a visible fruit', () {
      final s = quiet();
      final m = s.maze;
      s.fruit = Fruit(FruitType.cherry, m.fruitTile, 9.5);
      for (var i = 0; i < 940 && s.eatenFruit.isEmpty; i++) {
        s.update(0.01);
      }
      expect(s.eatenFruit, [FruitType.cherry]);
    });

    test('type per level', () {
      FruitType t(int l) => fruitForLevel(l);
      expect(t(1), FruitType.cherry);
      expect(t(2), FruitType.strawberry);
      expect([t(3), t(4)], everyElement(FruitType.orange));
      expect([t(5), t(6)], everyElement(FruitType.apple));
      expect([t(7), t(8)], everyElement(FruitType.melon));
      expect([t(9), t(10)], everyElement(FruitType.grapes));
      expect([t(11), t(12)], everyElement(FruitType.bell));
      expect([t(13), t(40)], everyElement(FruitType.key));
    });

    test('Hell keeps the fruit off the minimap', () {
      expect(quiet(d: Difficulty.hard).minimapShowsFruit, isTrue);
      final s = quiet(d: Difficulty.hell)
        ..fruit = Fruit(FruitType.cherry, 0, 9);
      expect(s.minimapShowsFruit, isFalse);
      MinimapPainter(
        s,
        0,
      ).paint(ui.Canvas(ui.PictureRecorder()), const ui.Size(220, 244));
    });
  });
}
