import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghost_hunt/audio/sfx.dart';
import 'package:ghost_hunt/game/game_state.dart';
import 'package:ghost_hunt/main.dart';
import 'package:ghost_hunt/ui/arcade_layout.dart';
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
        expect(find.text('Hide map'), findsOneWidget);
        await tester.tap(find.text('Hide map'));
        await tester.pump();
        expect(find.text('Map'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in const [
    Size(390, 844),
    Size(620, 800),
    Size(844, 390),
    Size(1280, 800),
  ]) {
    testWidgets('easy HUD fits a $size window', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            difficulty: Difficulty.easy,
            sfx: Sfx(),
            seed: 3,
            profile: Profile()
              ..coins = 123
              ..highScore = 4560,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 33));
      final window = Offset.zero & size;
      for (final t in [
        '1UP',
        'HIGH SCORE',
        '4560',
        '123',
        'LEVEL 1',
        'READY!',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
        final r = tester.getRect(find.text(t));
        expect(window.contains(r.topLeft), isTrue, reason: t);
        expect(window.contains(r.bottomRight), isTrue, reason: t);
      }
      expect(
        tester.widget<Text>(find.text('HIGH SCORE')).style!.fontFamily,
        'PressStart2P',
      );
      final lives = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PacIcon,
      );
      expect(lives, findsNWidgets(3));
      // The pack buttons never cover the maze.
      final paint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is TopDownPainter,
        ),
      );
      final painter = paint.painter! as TopDownPainter;
      final layout = ArcadeLayout(size, painter.s.maze, painter.safe);
      final field = layout.field;
      // HUD rows hug the maze, READY! is inside it.
      for (final t in ['1UP', 'HIGH SCORE', '4560']) {
        final r = tester.getRect(find.text(t));
        expect(r.bottom, lessThanOrEqualTo(field.top), reason: t);
        expect(
          r.top,
          greaterThanOrEqualTo(field.top - 3 * layout.cell),
          reason: t,
        );
      }
      final below = tester.getRect(find.text('LEVEL 1'));
      expect(below.top, greaterThanOrEqualTo(field.bottom));
      expect(below.bottom, lessThanOrEqualTo(field.bottom + 2 * layout.cell));
      final ready = tester.getRect(find.text('READY!'));
      expect(field.contains(ready.center), isTrue);
      for (final p in [PowerUp.speed, PowerUp.invisible, PowerUp.phase]) {
        final r = tester.getRect(find.text(p.emoji));
        expect(r.overlaps(field), isFalse, reason: '$p');
        expect(window.contains(r.center), isTrue, reason: '$p');
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
