import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghost_hunt/game/fruit.dart';
import 'package:ghost_hunt/ui/sprites.dart';

void main() {
  test('every classic fruit has a sprite and a glow colour', () {
    for (final t in FruitType.values) {
      final rec = PictureRecorder();
      drawFruit(Canvas(rec), const Offset(20, 20), 16, t);
      expect(fruitColor(t).a, 1);
      rec.endRecording();
    }
    expect(FruitType.values.length, 8);
  });
}
