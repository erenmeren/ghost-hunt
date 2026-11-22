import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghost_hunt/audio/sfx.dart';
import 'package:ghost_hunt/game/game_state.dart';
import 'package:ghost_hunt/main.dart';
import 'package:ghost_hunt/ui/game_screen.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('menu shows the three modes', (tester) async {
    await tester.pumpWidget(const GhostHuntApp());
    expect(find.text('EASY'), findsOneWidget);
    expect(find.text('HARD'), findsOneWidget);
    expect(find.text('HELL'), findsOneWidget);
  });

  for (final d in Difficulty.values) {
    testWidgets('${d.name} mode runs for 12 seconds with input', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: GameScreen(difficulty: d, sfx: Sfx(), seed: 3),
      ));
      final keys = [
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowDown,
      ];
      for (var i = 0; i < 12 * 30; i++) {
        if (i % 25 == 0) await tester.sendKeyEvent(keys[(i ~/ 25) % 4]);
        await tester.pump(const Duration(milliseconds: 33));
      }
      if (d != Difficulty.easy) {
        expect(find.text('Haritayı kapat'), findsOneWidget);
        await tester.tap(find.text('Haritayı kapat'));
        await tester.pump();
        expect(find.text('Harita'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
