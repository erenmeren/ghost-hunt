import 'package:flutter_test/flutter_test.dart';
import 'package:ghost_hunt/game/economy.dart';
import 'package:ghost_hunt/game/entities.dart';
import 'package:ghost_hunt/game/game_state.dart';
import 'package:ghost_hunt/game/maze.dart';

GameState _playing(Difficulty d, Profile p) {
  final s = GameState(difficulty: d, seed: 1, profile: p);
  while (s.phase != Phase.playing) {
    s.update(0.05);
  }
  return s;
}

void main() {
  test('shop: buying costs coins, cannot overspend, upgrades cap', () {
    final p = Profile()..coins = 200;
    expect(p.buyPack(PowerUp.speed), isTrue);
    expect(p.coins, 200 - PowerUp.speed.price);
    expect(p.packsOf(PowerUp.speed), 1);
    expect(p.buyPack(PowerUp.phase), isFalse); // 140 < 150
    p.coins = 100000;
    for (var i = 0; i < 5; i++) {
      p.buyUpgrade(Upgrade.slots);
    }
    expect(p.levelOf(Upgrade.slots), Upgrade.slots.maxLevel);
    expect(p.upgradePrice(Upgrade.slots), isNull);
  });

  test('profile survives a JSON round trip; garbage gives a fresh one', () {
    final p = Profile()
      ..coins = 77
      ..buyUpgrade(Upgrade.hearing);
    p.coins = 500;
    p.buyPack(PowerUp.sonar);
    final q = Profile.fromJson(p.toJson());
    expect(q.coins, p.coins);
    expect(q.packsOf(PowerUp.sonar), 1);
    expect(Profile.fromJson('{nope').coins, 0);
  });

  test('packs: limited per level, timed, consumed', () {
    final p = Profile();
    for (final u in PowerUp.values) {
      p.packs[u] = 3;
    }
    final s = _playing(Difficulty.hard, p);
    final base = s.playerSpeed;
    expect(s.usePowerUp(PowerUp.speed), isTrue);
    expect(s.playerSpeed, closeTo(base * 1.4, 1e-9));
    expect(s.usePowerUp(PowerUp.speed), isFalse); // already running
    expect(s.usePowerUp(PowerUp.sonar), isTrue);
    expect(s.showBeam, isTrue);
    expect(s.packsLeftThisLevel, 0);
    expect(s.usePowerUp(PowerUp.invisible), isFalse); // out of slots
    expect(p.packsOf(PowerUp.speed), 2);
    for (var i = 0; i < 120; i++) {
      s.update(0.05);
    }
    expect(s.isActive(PowerUp.speed), isFalse);
  });

  test('sonar is the only visual hint in Hell', () {
    final p = Profile()..packs[PowerUp.sonar] = 1;
    final s = _playing(Difficulty.hell, p);
    expect(s.showBeam, isFalse);
    expect(s.minimapShowsPac, isFalse);
    s.usePowerUp(PowerUp.sonar);
    expect(s.showBeam, isTrue);
    expect(s.minimapShowsPac, isTrue);
  });

  test('sonar cannot be used in Easy', () {
    final p = Profile()..packs[PowerUp.sonar] = 1;
    final s = _playing(Difficulty.easy, p);
    expect(s.usePowerUp(PowerUp.sonar), isFalse);
    expect(p.packsOf(PowerUp.sonar), 1);
  });

  test('phase lets you walk through an inner wall, never the border', () {
    final p = Profile()..packs[PowerUp.phase] = 1;
    final s = _playing(Difficulty.easy, p);
    final m = s.maze;
    // Player starts above the ghost house in a horizontal corridor;
    // the tile straight up is an inner wall.
    final up = m.neighbor(s.player.tile, Dir.up);
    expect(m.pacWalkable(up), isFalse);
    s.usePowerUp(PowerUp.phase);
    s.inputDir(Dir.up);
    final startY = m.yOf(s.player.tile);
    for (var i = 0; i < 10; i++) {
      s.update(0.05);
    }
    expect(m.yOf(s.player.tile), lessThan(startY));
    for (var i = 0; i < 200; i++) {
      s.update(0.05);
      expect(m.yOf(s.player.tile), greaterThan(0)); // border holds
    }
  });

  test('invisible: Pac-Man ignores you', () {
    final p = Profile()..packs[PowerUp.invisible] = 1;
    final s = _playing(Difficulty.hard, p);
    s.brain.carelessness = 0;
    for (final g in s.aiGhosts) {
      g.state = GhostState.inHouse;
      g.timer = 1e9;
    }
    // Put the player two tiles in front of Pac-Man in his corridor.
    final m = s.maze;
    final pac = s.pac;
    var t = pac.tile;
    var d = Dir.none;
    for (final dir in moveDirs) {
      final a = m.neighbor(t, dir), b = m.neighbor(a, dir);
      if (m.pacWalkable(a) && m.pacWalkable(b)) {
        d = dir;
        t = b;
        break;
      }
    }
    expect(d, isNot(Dir.none));
    pac.progress = 0;
    s.player
      ..placeAt(t, d.opposite)
      ..state = GhostState.active;
    expect(s.brain.decide(s), isNot(d)); // sees you, runs
    s.usePowerUp(PowerUp.invisible);
    expect(s.invisible, isTrue);
    expect(s.brain.decide(s), d); // walks right into you (nearest pellet)
  });

  test('catching Pac-Man pays, more in Hell', () {
    expect(
      Rewards.playerCatch(Difficulty.hell, 1),
      4 * Rewards.playerCatch(Difficulty.easy, 1),
    );
    expect(
      Rewards.playerCatch(Difficulty.easy, 1),
      greaterThan(Rewards.playerCatch(Difficulty.easy, 0)),
    );
  });
}
