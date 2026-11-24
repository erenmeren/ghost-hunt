import 'dart:math' as math;
import 'dart:ui';

import '../game/fruit.dart';

const pacYellow = Color(0xFFFFE000);
const frightBlue = Color(0xFF2121FF);

/// The runner: a walking lantern. [flare] (0..1) makes the flame jump while
/// he eats, [facing] is where his eyes look and the flame leans away from.
void drawRunner(
  Canvas c,
  Offset center,
  double r,
  double flare, {
  double facing = 0,
  double alpha = 1,
}) {
  final brass = Paint()
    ..color = const Color(0xFFC07A2C).withValues(alpha: alpha);
  final dark = Paint()
    ..color = const Color(0xFF2A1608).withValues(alpha: alpha);
  final lx = math.cos(facing), ly = math.sin(facing);
  Rect box(double l, double t, double w, double h) =>
      Rect.fromLTWH(center.dx + l * r, center.dy + t * r, w * r, h * r);
  Offset at(double x, double y) => Offset(center.dx + x * r, center.dy + y * r);

  // Glow.
  c.drawCircle(
    center,
    r * (1.15 + 0.15 * flare),
    Paint()..color = pacYellow.withValues(alpha: 0.16 * alpha),
  );
  // Feet take turns.
  final step = flare * 0.14;
  c.drawRect(box(-0.5, 0.72, 0.34, 0.28 - step), brass);
  c.drawRect(box(0.16, 0.72, 0.34, 0.14 + step), brass);
  // Handle.
  c.drawArc(
    box(-0.36, -1.08, 0.72, 0.66),
    math.pi,
    math.pi,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.14
      ..color = brass.color,
  );
  // Glass with the flame inside.
  c.drawRRect(
    RRect.fromRectAndRadius(
      box(-0.72, -0.5, 1.44, 1.14),
      Radius.circular(r * 0.3),
    ),
    Paint()
      ..color = Color.lerp(
        const Color(0xFFFF9E2C),
        pacYellow,
        flare,
      )!.withValues(alpha: alpha),
  );
  final tip = at(-lx * 0.22, -0.28 - 0.18 * flare);
  final flame = Path()
    ..moveTo(tip.dx, tip.dy)
    ..quadraticBezierTo(
      at(0.5, 0.1).dx,
      at(0, 0.05).dy,
      at(0, 0.56).dx,
      at(0, 0.56).dy,
    )
    ..quadraticBezierTo(at(-0.5, 0.1).dx, at(0, 0.05).dy, tip.dx, tip.dy);
  c.drawPath(
    flame,
    Paint()..color = const Color(0xFFFFF6C8).withValues(alpha: alpha),
  );
  // Roof and base.
  c.drawPath(
    Path()..addPolygon([
      at(-0.4, -0.78),
      at(0.4, -0.78),
      at(0.86, -0.42),
      at(-0.86, -0.42),
    ], true),
    brass,
  );
  c.drawRect(box(-0.8, 0.56, 1.6, 0.2), brass);
  // Eyes on the glass.
  for (final side in [-1.0, 1.0]) {
    c.drawOval(
      Rect.fromCenter(
        center: at(side * 0.28 + lx * 0.22, 0.06 + ly * 0.16),
        width: r * 0.2,
        height: r * 0.34,
      ),
      dark,
    );
  }
}

/// Pulse of the player's ghost: 0..1..0 twice a second.
double playerPulse(double clock) => 0.5 + 0.5 * math.sin(clock * 4 * math.pi);

/// [c] with more saturation and brightness; [pulse] (0..1) lifts it further.
Color vividColor(Color c, double pulse) {
  final grey = (c.r + c.g + c.b) / 3;
  double push(double v) => math.max(0, grey + (v - grey) * 1.4);
  final r = push(c.r), g = push(c.g), b = push(c.b);
  final top = math.max(r, math.max(g, b));
  if (top == 0) return c;
  return Color.lerp(
    Color.from(alpha: c.a, red: r / top, green: g / top, blue: b / top),
    const Color(0xFFFFFFFF),
    0.1 + 0.4 * pulse,
  )!;
}

/// Soft light behind the player's ghost. It fades out to nothing, so there is
/// no outline.
void drawPlayerGlow(
  Canvas c,
  Offset center,
  double r,
  Color color,
  double pulse,
) {
  final reach = r * (1.6 + 0.35 * pulse);
  final strength = 0.35 + 0.5 * pulse;
  c.drawCircle(
    center,
    reach,
    Paint()
      ..shader = Gradient.radial(
        center,
        reach,
        [
          color.withValues(alpha: strength),
          color.withValues(alpha: strength * 0.5),
          color.withValues(alpha: 0),
        ],
        const [0, 0.5, 1],
      ),
  );
}

/// A wisp: hooded teardrop whose tip and tail trail behind its movement.
/// Fills a square of side 2r around [center]. The player's ghost passes
/// [pulse] (0..1) to burn brighter than the others and glow.
void drawGhost(
  Canvas c,
  Offset center,
  double r, {
  required Color color,
  bool frightened = false,
  bool flashing = false,
  bool eyesOnly = false,
  double lookX = 0,
  double lookY = 0,
  double wobble = 0,
  double alpha = 1,
  double? pulse,
}) {
  Offset at(double x, double y) => Offset(center.dx + x * r, center.dy + y * r);
  final sway = math.sin(wobble * 1.6) * 0.14;
  var ink = frightened ? frightBlue : color;
  if (frightened && flashing) ink = const Color(0xFFFFFFFF);
  if (pulse != null) {
    // The glow keeps the ghost's own colour, frightened or not.
    drawPlayerGlow(c, center, r, vividColor(color, 0), pulse);
    ink = vividColor(ink, pulse);
  }

  if (!eyesOnly) {
    final tip = at(-0.5 * lookX + sway, -1.05);
    final tail = at(-0.75 * lookX - sway * 1.6, 1.02);
    Path cubic(Path p, Offset a, Offset b, Offset to) =>
        p..cubicTo(a.dx, a.dy, b.dx, b.dy, to.dx, to.dy);
    final body = Path()..moveTo(tip.dx, tip.dy);
    cubic(body, at(0.1, -0.92), at(0.84, -0.72), at(0.84, -0.02));
    cubic(body, at(0.84, 0.58), at(0.4, 0.66), tail);
    cubic(body, at(-0.4, 0.66), at(-0.84, 0.58), at(-0.84, -0.02));
    cubic(body, at(-0.84, -0.72), at(-0.1, -0.92), tip);
    body.close();
    c.drawPath(body, Paint()..color = ink.withValues(alpha: alpha));
    // Two drifting sparks for arms.
    final spark = Paint()..color = ink.withValues(alpha: alpha * 0.85);
    c.drawCircle(at(-0.9, 0.46 + sway), r * 0.13, spark);
    c.drawCircle(at(0.9, 0.46 - sway), r * 0.13, spark);
  }

  final hollow = Paint()
    ..color = (eyesOnly ? color : const Color(0xFF120A1E)).withValues(
      alpha: alpha,
    );
  final fx = lookX * 0.2, fy = -0.12 + lookY * 0.18;
  if (frightened && !eyesOnly) {
    // Crossed-out eyes and a small round gasp.
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * 0.12)
      ..color = (flashing ? const Color(0xFF120A1E) : const Color(0xFFE9F3C8))
          .withValues(alpha: alpha);
    for (final side in [-0.36, 0.36]) {
      c.drawLine(at(side - 0.16, -0.28), at(side + 0.16, 0.04), pen);
      c.drawLine(at(side + 0.16, -0.28), at(side - 0.16, 0.04), pen);
    }
    c.drawCircle(at(0, 0.32), r * 0.12, pen);
    return;
  }
  for (final side in [-1.0, 1.0]) {
    // Slanted hollow eyes with a pinpoint of light.
    final eye = at(side * 0.36 + fx, fy);
    c.save();
    c.translate(eye.dx, eye.dy);
    c.rotate(side * 0.35);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 0.36, height: r * 0.58),
      hollow,
    );
    c.restore();
    c.drawCircle(
      eye.translate(lookX * r * 0.07, lookY * r * 0.12),
      r * 0.09,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
    );
  }
}

/// Pixel colours used by the fruit bitmaps.
const _fruitInk = {
  'p': Color(0xFF7B3FC4),
  'P': Color(0xFFB98AF0),
  'y': Color(0xFFF6D93B),
  'Y': Color(0xFFFFF3A6),
  'o': Color(0xFFF08A24),
  'O': Color(0xFFC4600F),
  'g': Color(0xFF3FA34D),
  'G': Color(0xFF9BDB5A),
  'b': Color(0xFF7A4B24),
  'w': Color(0xFFFFFFFF),
  'm': Color(0xFFE83E8C),
  'k': Color(0xFF1C1320),
};

const _fruitPixels = {
  FruitType.plum: [
    '.....bb...',
    '....bgg...',
    '..ppppppp.',
    '.pPPpppppp',
    '.pPpppppppp',
    '.pppppppppp',
    '.pppppppppp',
    '..pppppppp.',
    '...pppppp..',
    '....pppp...',
  ],
  FruitType.lemon: [
    '.......gg..',
    '......gg...',
    '...yyyyy...',
    '..yYYyyyy..',
    '.yYYyyyyyy.',
    'yyYyyyyyyyy',
    '.yyyyyyyyy.',
    '..yyyyyyy..',
    '...yyyyy...',
    '.....y.....',
  ],
  FruitType.grapes: [
    '.....b.....',
    '...ggbgg...',
    '.PP.PP.PP..',
    '.pp.pp.pp..',
    '...........',
    '..PP.PP....',
    '..pp.pp....',
    '...........',
    '....PP.....',
    '....pp.....',
  ],
  FruitType.kiwi: [
    '...bbbbb...',
    '..bGGGGGb..',
    '.bGGkGkGGb.',
    'bGGkwwwkGGb',
    'bGGGwwwGGGb',
    'bGkwwwwwkGb',
    'bGGGwwwGGGb',
    '.bGkGGGkGb.',
    '..bGGGGGb..',
    '...bbbbb...',
  ],
  FruitType.pumpkin: [
    '.....gg....',
    '.....g.....',
    '..oooOooo..',
    '.ooOooOooo.',
    'ooOoooOoooo',
    'ooOoooOoooo',
    'ooOoooOoooo',
    'ooOoooOoooo',
    '.oOoooOooo.',
    '..oooOooo..',
  ],
  FruitType.pineapple: [
    '..g..g..g..',
    '...ggggg...',
    '....ggg....',
    '...yOyOy...',
    '..yOyOyOy..',
    '..OyOyOyO..',
    '..yOyOyOy..',
    '..OyOyOyO..',
    '..yOyOyOy..',
    '...yOyOy...',
  ],
  FruitType.dragonfruit: [
    '.G..mm..G..',
    '..GmmmmG...',
    '.mmwwwwmm..',
    'Gmwkwwwkwm.',
    '.mwwwkwwwmG',
    '.mwkwwwkwm.',
    'GmwwwkwwwmG',
    '.mmwwwwmm..',
    '..GmmmmG...',
    '....mm.....',
  ],
  FruitType.starfruit: [
    '.....y.....',
    '....yYy....',
    '....yYy....',
    'yyyyYYYyyyy',
    '.yYYYYYYYy.',
    '..yYYYYYy..',
    '..yYYYYYy..',
    '.yYYyyyYYy.',
    '.yYy...yYy.',
    'yy.......yy',
  ],
};

/// Glow colour of a fruit in the 3D views and on the minimap.
Color fruitColor(FruitType t) => switch (t) {
  FruitType.plum => _fruitInk['p']!,
  FruitType.lemon => _fruitInk['y']!,
  FruitType.grapes => _fruitInk['P']!,
  FruitType.kiwi => _fruitInk['G']!,
  FruitType.pumpkin => _fruitInk['o']!,
  FruitType.pineapple => const Color(0xFFE5B52A),
  FruitType.dragonfruit => _fruitInk['m']!,
  FruitType.starfruit => _fruitInk['Y']!,
};

/// Pixel-art fruit filling a square of side 2r around [center].
void drawFruit(
  Canvas c,
  Offset center,
  double r,
  FruitType type, {
  double alpha = 1,
}) {
  final rows = _fruitPixels[type]!;
  final px = 2 * r / 11;
  final left = center.dx - r, top = center.dy - px * rows.length / 2;
  final paint = Paint()..isAntiAlias = false;
  for (var y = 0; y < rows.length; y++) {
    for (var x = 0; x < rows[y].length; x++) {
      final ink = _fruitInk[rows[y][x]];
      if (ink == null) continue;
      paint.color = ink.withValues(alpha: alpha);
      c.drawRect(
        Rect.fromLTWH(left + x * px, top + y * px, px + 0.2, px + 0.2),
        paint,
      );
    }
  }
}
