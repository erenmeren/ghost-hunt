/// Bonus items. Only Pac-Man can eat them; ghosts pass straight over.
enum FruitType { cherry, strawberry, orange, apple, melon, grapes, bell, key }

/// Which bonus item a level offers (the classic arcade order).
FruitType fruitForLevel(int level) => switch (level) {
  <= 1 => FruitType.cherry,
  2 => FruitType.strawberry,
  <= 4 => FruitType.orange,
  <= 6 => FruitType.apple,
  <= 8 => FruitType.melon,
  <= 10 => FruitType.grapes,
  <= 12 => FruitType.bell,
  _ => FruitType.key,
};

/// A bonus item lying in the maze.
class Fruit {
  Fruit(this.type, this.tile, this.timeLeft);

  final FruitType type;
  final int tile;
  double timeLeft;
}
