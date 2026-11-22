import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghost_hunt/audio/sfx.dart';
import 'package:ghost_hunt/game/game_state.dart';
import 'package:ghost_hunt/main.dart';
import 'package:ghost_hunt/ui/game_screen.dart';
import 'package:ghost_hunt/ui/raycast_painter.dart';
import 'package:ghost_hunt/ui/top_down_painter.dart';
import 'package:ghost_hunt/game/economy.dart';
import 'package:ghost_hunt/ui/shop_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('menu shows the three modes and the shop', (tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GhostHuntApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('SHOP'), findsOneWidget);
    expect(find.text('EASY'), findsOneWidget);
    expect(find.text('HARD'), findsOneWidget);
    expect(find.text('HELL'), findsOneWidget);
  });

  for (final d in Difficulty.values) {
    testWidgets('${d.name} mode runs for 12 seconds with input', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            difficulty: d,
            sfx: Sfx(),
            seed: 3,
            profile: Profile()..packs.updateAll((_, _) => 2),
          ),
        ),
      );
      // The game canvas must fill the whole window.
      final paint = find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            (w.painter is RaycastPainter || w.painter is TopDownPainter),
      );
      expect(tester.getSize(paint), const Size(844, 390));
      final keys = [
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowDown,
      ];
      for (var i = 0; i < 12 * 30; i++) {
        if (i % 25 == 0) await tester.sendKeyEvent(keys[(i ~/ 25) % 4]);
        if (i == 80) await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
        if (i == 140) await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
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

  testWidgets('shop buys a pack and shows the new balance', (tester) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = Profile()..coins = 100;
    await tester.pumpWidget(MaterialApp(home: ShopScreen(profile: p)));
    expect(find.text('🪙 100'), findsOneWidget);
    await tester.tap(find.text('🪙 60')); // speed pack
    await tester.pump();
    expect(p.packsOf(PowerUp.speed), 1);
    expect(find.text('🪙 40'), findsOneWidget);
  });
}
