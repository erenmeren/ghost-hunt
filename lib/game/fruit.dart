/// Bonus items. Only the runner can eat them; ghosts pass straight over.
enum FruitType {
  plum,
  lemon,
  grapes,
  kiwi,
  pumpkin,
  pineapple,
  dragonfruit,
  starfruit,
}

/// Which bonus item a level offers.
FruitType fruitForLevel(int level) => switch (level) {
  <= 1 => FruitType.plum,
  2 => FruitType.lemon,
  <= 4 => FruitType.grapes,
  <= 6 => FruitType.kiwi,
  <= 8 => FruitType.pumpkin,
  <= 10 => FruitType.pineapple,
  <= 12 => FruitType.dragonfruit,
  _ => FruitType.starfruit,
};

/// A bonus item lying in the maze.
class Fruit {
  Fruit(this.type, this.tile, this.timeLeft);

  final FruitType type;
  final int tile;
  double timeLeft;
}
