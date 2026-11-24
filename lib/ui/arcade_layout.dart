import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../game/maze.dart';

/// The bundled pixel font (assets/fonts, SIL OFL).
const pixelFont = 'PressStart2P';

/// Pixel-font text style. Glyphs are exactly [size] wide.
TextStyle pixelText(double size, {Color color = Colors.white}) => TextStyle(
  fontFamily: pixelFont,
  fontSize: size,
  height: 1,
  letterSpacing: 0,
  fontWeight: FontWeight.normal,
  color: color,
);

/// Where the overhead view and its HUD go: the maze with three tile rows of
/// score above and two rows of lives/bonus items below, centred in the
/// window.
class ArcadeLayout {
  ArcadeLayout(Size size, Maze m, [EdgeInsets safe = EdgeInsets.zero])
    : cell = math.min(
        math.max(1, size.width - safe.horizontal) / m.width,
        math.max(1, size.height - safe.vertical) / (m.height + 5),
      ) {
    final w = cell * m.width, h = cell * (m.height + topRows + bottomRows);
    final left = safe.left + (size.width - safe.horizontal - w) / 2;
    final top = safe.top + (size.height - safe.vertical - h) / 2;
    field = Rect.fromLTWH(left, top + cell * topRows, w, cell * m.height);
  }

  static const topRows = 3, bottomRows = 2;

  /// Size of one tile.
  final double cell;

  /// The maze itself.
  late final Rect field;

  /// Rect covering whole tiles; negative rows are the score rows.
  Rect tiles(double x, double y, double w, double h) => Rect.fromLTWH(
    field.left + x * cell,
    field.top + y * cell,
    w * cell,
    h * cell,
  );
}
