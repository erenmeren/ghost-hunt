import 'dart:convert';
import 'dart:math' as math;

import 'game_state.dart';

/// Consumable packs: bought in the shop, used during a level.
enum PowerUp { speed, invisible, phase, sonar }

extension PowerUpInfo on PowerUp {
  String get emoji => switch (this) {
    PowerUp.speed => '⚡',
    PowerUp.invisible => '👻',
    PowerUp.phase => '🧱',
    PowerUp.sonar => '📡',
  };

  String get title => switch (this) {
    PowerUp.speed => 'Speed pack',
    PowerUp.invisible => 'Invisibility',
    PowerUp.phase => 'Wall pass',
    PowerUp.sonar => 'Sonar',
  };

  String get description => switch (this) {
    PowerUp.speed => 'Move 40% faster for 5 seconds.',
    PowerUp.invisible => 'For 5 seconds Pac-Man can\'t see you or run from you. Catches still count.',
    PowerUp.phase =>
      'Pass through walls for 3 seconds, except the outer walls.',
    PowerUp.sonar =>
      'See Pac-Man\'s light and his spot on the map for 2 seconds. '
          'Hell\'s only visual hint.',
  };

  int get price => switch (this) {
    PowerUp.speed => 60,
    PowerUp.invisible => 120,
    PowerUp.phase => 150,
    PowerUp.sonar => 90,
  };

  /// Seconds the effect lasts.
  double get duration => switch (this) {
    PowerUp.speed => 5,
    PowerUp.invisible => 5,
    PowerUp.phase => 3,
    PowerUp.sonar => 2,
  };
}

/// Permanent upgrades, bought once per level of the upgrade.
enum Upgrade { baseSpeed, hearing, slots }

extension UpgradeInfo on Upgrade {
  String get emoji => switch (this) {
    Upgrade.baseSpeed => '🏃',
    Upgrade.hearing => '👂',
    Upgrade.slots => '🎒',
  };

  String get title => switch (this) {
    Upgrade.baseSpeed => 'Base speed',
    Upgrade.hearing => 'Sharp ears',
    Upgrade.slots => 'Big bag',
  };

  String get description => switch (this) {
    Upgrade.baseSpeed => 'Each upgrade level makes you 4% faster, permanently.',
    Upgrade.hearing => 'Hear Pac-Man from 4 tiles farther per upgrade level.',
    Upgrade.slots => 'Use 1 more pack per level.',
  };

  int get maxLevel => 3;

  int priceFor(int current) => switch (this) {
    Upgrade.baseSpeed => 200 * (current + 1),
    Upgrade.hearing => 150 * (current + 1),
    Upgrade.slots => 300 * (current + 1),
  };
}

/// Coins, packs and upgrades. Pure Dart; persisted as JSON by the app.
class Profile {
  Profile();

  /// A fresh player can afford a couple of packs right away.
  static const welcomeCoins = 150;

  int coins = 0;
  int highScore = 0;
  final Map<PowerUp, int> packs = {for (final p in PowerUp.values) p: 0};
  final Map<Upgrade, int> upgrades = {for (final u in Upgrade.values) u: 0};

  /// Called after every change so the app can save.
  void Function()? onChanged;

  int packsOf(PowerUp p) => packs[p] ?? 0;
  int levelOf(Upgrade u) => upgrades[u] ?? 0;

  /// How many packs may be used in one level.
  int get slotsPerLevel => 2 + levelOf(Upgrade.slots);
  double get speedMultiplier => 1 + 0.04 * levelOf(Upgrade.baseSpeed);
  double get hearingBonus => 4.0 * levelOf(Upgrade.hearing);

  bool canBuyPack(PowerUp p) => coins >= p.price;

  bool buyPack(PowerUp p) {
    if (!canBuyPack(p)) return false;
    coins -= p.price;
    packs[p] = packsOf(p) + 1;
    onChanged?.call();
    return true;
  }

  int? upgradePrice(Upgrade u) {
    final l = levelOf(u);
    return l >= u.maxLevel ? null : u.priceFor(l);
  }

  bool buyUpgrade(Upgrade u) {
    final price = upgradePrice(u);
    if (price == null || coins < price) return false;
    coins -= price;
    upgrades[u] = levelOf(u) + 1;
    onChanged?.call();
    return true;
  }

  bool consumePack(PowerUp p) {
    if (packsOf(p) <= 0) return false;
    packs[p] = packsOf(p) - 1;
    onChanged?.call();
    return true;
  }

  void addCoins(int n) {
    if (n <= 0) return;
    coins += n;
    onChanged?.call();
  }

  /// Remembers [score] if it beats the best one so far.
  void recordScore(int score) {
    if (score <= highScore) return;
    highScore = score;
    onChanged?.call();
  }

  String toJson() => jsonEncode({
    'coins': coins,
    'highScore': highScore,
    'packs': {for (final e in packs.entries) e.key.name: e.value},
    'upgrades': {for (final e in upgrades.entries) e.key.name: e.value},
  });

  static Profile fromJson(String? raw) {
    final p = Profile();
    if (raw == null || raw.isEmpty) return p..coins = welcomeCoins;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      p.coins = (j['coins'] as num?)?.toInt() ?? 0;
      p.highScore = (j['highScore'] as num?)?.toInt() ?? 0;
      final packs = (j['packs'] as Map?) ?? const {};
      for (final u in PowerUp.values) {
        p.packs[u] = (packs[u.name] as num?)?.toInt() ?? 0;
      }
      final ups = (j['upgrades'] as Map?) ?? const {};
      for (final u in Upgrade.values) {
        p.upgrades[u] = math.min(
          u.maxLevel,
          (ups[u.name] as num?)?.toInt() ?? 0,
        );
      }
    } catch (_) {
      // Corrupt save: start fresh rather than crash.
    }
    return p;
  }
}

/// Coin rewards.
class Rewards {
  static int multiplier(Difficulty d) => switch (d) {
    Difficulty.easy => 1,
    Difficulty.hard => 2,
    Difficulty.hell => 4,
  };

  /// Catching Pac-Man yourself: 20 base, up to +20 the fewer pellets he ate.
  static int playerCatch(Difficulty d, double pelletsLeftFraction) =>
      (20 + 20 * pelletsLeftFraction.clamp(0.0, 1.0)).round() * multiplier(d);

  /// A teammate caught him.
  static int teamCatch(Difficulty d) => 5 * multiplier(d);

  /// Clearing a level (Pac-Man out of lives).
  static int levelWin(Difficulty d, int level) =>
      (25 + 10 * level) * multiplier(d);
}

/// Points for the arcade score (the mode multiplies them like coins).
class Score {
  /// Your own catch: 500, up to +500 the fewer pellets he ate.
  static int playerCatch(Difficulty d, double pelletsLeftFraction) =>
      (50 + 50 * pelletsLeftFraction.clamp(0.0, 1.0)).round() *
      10 *
      Rewards.multiplier(d);

  static int teamCatch(Difficulty d) => 100 * Rewards.multiplier(d);

  static int levelWin(Difficulty d, int level) =>
      (800 + 200 * level) * Rewards.multiplier(d);
}
