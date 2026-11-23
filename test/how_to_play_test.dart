import 'package:flutter_test/flutter_test.dart';
import 'package:ghost_hunt/game/economy.dart';
import 'package:ghost_hunt/main.dart';
import 'package:ghost_hunt/ui/how_to_play_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Finder inPage(Finder f) =>
      find.descendant(of: find.byType(HowToPlayScreen), matching: f);

  testWidgets('menu opens how-to-play and back returns to the menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GhostHuntApp());
    await tester.pumpAndSettle();

    final open = find.text('HOW TO PLAY');
    expect(open, findsOneWidget);
    // The menu still fits the window: the new button is on screen.
    final r = tester.getRect(open);
    expect(r.top, greaterThanOrEqualTo(0));
    expect(r.bottom, lessThanOrEqualTo(1000));
    expect(tester.takeException(), isNull);
    await tester.tap(open);
    await tester.pumpAndSettle();

    expect(find.byType(HowToPlayScreen), findsOneWidget);
    expect(inPage(find.text('HOW TO PLAY')), findsOneWidget); // app bar
    for (final mode in ['EASY', 'HARD', 'HELL']) {
      expect(inPage(find.text(mode)), findsOneWidget);
    }
    for (final p in PowerUp.values) {
      expect(inPage(find.text(p.title)), findsOneWidget);
    }
    for (final u in Upgrade.values) {
      expect(inPage(find.text(u.title)), findsOneWidget);
    }

    // The page scrolls all the way down to the controls.
    final scrollable = inPage(find.byType(Scrollable));
    await tester.scrollUntilVisible(
      inPage(find.text('Controls')),
      300,
      scrollable: scrollable,
    );
    await tester.scrollUntilVisible(
      inPage(find.text('Pause')),
      300,
      scrollable: scrollable,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(HowToPlayScreen), findsNothing);
    expect(find.text('GHOST HUNT'), findsOneWidget);
    expect(find.text('EASY'), findsOneWidget);
    expect(find.text('HOW TO PLAY'), findsOneWidget);
  });
}
