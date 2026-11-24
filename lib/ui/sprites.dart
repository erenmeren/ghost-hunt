import 'dart:math' as math;
import 'dart:ui';

import '../game/fruit.dart';

const pacYellow = Color(0xFFFFE000);
const frightBlue = Color(0xFF2121FF);
const pelletColor = Color(0xFFFFB8AE);

/// Pac-Man as a circle with a mouth. [facing] is the mouth direction.
void drawPacman(
  Canvas c,
  Offset center,
  double r,
  double mouthOpen, {
  double facing = 0,
  double alpha = 1,
}) {
  final m = 0.05 + mouthOpen * 0.75; // half-angle of the mouth
  final paint = Paint()..color = pacYellow.withValues(alpha: alpha);
  c.drawArc(
    Rect.fromCircle(center: center, radius: r),
    facing + m,
    2 * math.pi - 2 * m,
    true,
    paint,
  );
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

/// Strong neon light around the player's ghost: a wide halo that pulses
/// at 2 Hz and fades out to nothing (no ring or marker).
void drawPlayerGlow(
  Canvas c,
  Offset center,
  double r,
  Color color,
  double pulse,
) {
  final reach = r * (2.1 + 0.6 * pulse);
  final strength = 0.55 + 0.45 * pulse;
  c.drawCircle(
    center,
    reach,
    Paint()
      ..shader = Gradient.radial(
        center,
        reach,
        [
          color.withValues(alpha: strength),
          color.withValues(alpha: strength * 0.55),
          color.withValues(alpha: strength * 0.2),
          color.withValues(alpha: 0),
        ],
        const [0.25, 0.5, 0.75, 1],
      ),
  );
}

/// Arcade style ghost filling a square of side 2r around [center]. Only the
/// player's ghost passes [pulse] (0..1): it is drawn as a neon sign.
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
  final left = center.dx - r, right = center.dx + r;
  final top = center.dy - r, bottom = center.dy + r;
  if (pulse != null) {
    // Neon: the light keeps the ghost's own colour, frightened or not.
    drawPlayerGlow(c, center, r, vividColor(color, 0), pulse);
  }
  if (!eyesOnly) {
    final body = Path()
      ..moveTo(left, bottom)
      ..lineTo(left, top + r)
      ..arcToPoint(
        Offset(right, top + r),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(right, bottom);
    // Wavy skirt.
    const bumps = 4;
    final bw = 2 * r / bumps;
    final phase = (wobble * 2).floor().isEven ? 0.0 : bw / 2;
    for (var i = 0; i < bumps; i++) {
      final x0 = right - i * bw - phase;
      body.lineTo(math.max(left, x0 - bw / 2), bottom - r * 0.22);
      body.lineTo(math.max(left, x0 - bw), bottom);
    }
    body
      ..lineTo(left, bottom)
      ..close();
    var bodyColor = frightened ? frightBlue : color;
    if (frightened && flashing) bodyColor = const Color(0xFFFFFFFF);
    if (pulse != null) bodyColor = vividColor(bodyColor, pulse);
    c.drawPath(body, Paint()..color = bodyColor.withValues(alpha: alpha));
    if (pulse != null) {
      // Thin bright glowing outline, like a neon tube.
      final tube = vividColor(color, 1);
      c.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.3
          ..color = tube.withValues(alpha: alpha * (0.5 + 0.4 * pulse))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.28),
      );
      c.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, r * 0.07)
          ..color = Color.lerp(
            tube,
            const Color(0xFFFFFFFF),
            0.55,
          )!.withValues(alpha: alpha),
      );
    }
    if (frightened) {
      final face = Paint()
        ..color = (flashing ? const Color(0xFFFF0000) : pelletColor).withValues(
          alpha: alpha,
        );
      c.drawCircle(
        Offset(center.dx - r * 0.35, center.dy - r * 0.2),
        r * 0.13,
        face,
      );
      c.drawCircle(
        Offset(center.dx + r * 0.35, center.dy - r * 0.2),
        r * 0.13,
        face,
      );
      final mouth = Path()..moveTo(left + r * 0.25, center.dy + r * 0.35);
      for (var i = 1; i <= 6; i++) {
        mouth.lineTo(
          left + r * 0.25 + i * r * 0.25,
          center.dy + r * (i.isOdd ? 0.2 : 0.35),
        );
      }
      c.drawPath(
        mouth,
        face
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, r * 0.08),
      );
      return;
    }
  }
  final white = Paint()
    ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha);
  final blue = Paint()
    ..color = const Color(0xFF2121DE).withValues(alpha: alpha);
  for (final s in [-1.0, 1.0]) {
    final eye = Offset(center.dx + s * r * 0.38, center.dy - r * 0.18);
    c.drawOval(
      Rect.fromCenter(
        center: eye.translate(lookX * r * 0.08, lookY * r * 0.08),
        width: r * 0.55,
        height: r * 0.68,
      ),
      white,
    );
    c.drawCircle(
      eye.translate(lookX * r * 0.2, lookY * r * 0.2),
      r * 0.15,
      blue,
    );
  }
}

/// Pixel colours used by the fruit bitmaps.
const _fruitInk = {
  'r': Color(0xFFE5232B),
  'R': Color(0xFFFF8A8A),
  'd': Color(0xFF9E1018),
  'g': Color(0xFF2EA64A),
  'G': Color(0xFF8AE05A),
  'b': Color(0xFF7A4B24),
  'o': Color(0xFFFF9A1F),
  'O': Color(0xFFFFC866),
  'y': Color(0xFFFFE000),
  'Y': Color(0xFFFFF59A),
  'p': Color(0xFF8B3FD0),
  'P': Color(0xFFC79BFF),
  'c': Color(0xFF3FD2E8),
  'w': Color(0xFFFFFFFF),
  'k': Color(0xFF1C1320),
  'm': Color(0xFFB8F0A0),
};

const _fruitPixels = {
  FruitType.cherry: [
    '......gg...',
    '.....g.gg..',
    '....g...g..',
    '...g....g..',
    '..rrr..rrr.',
    '.rRrrr.rRrr',
    '.rrrrr.rrrr',
    '.rrrdr.rrrd',
    '..rdd...rdd',
    '...........',
  ],
  FruitType.strawberry: [
    '....ggg....',
    '..ggGgGgg..',
    '.rrrrgrrrr.',
    '.rRrrrrRrr.',
    '.rrYrrrYrr.',
    '..rrrYrrr..',
    '..rYrrrYr..',
    '...rrrrr...',
    '....rYr....',
    '.....r.....',
  ],
  FruitType.orange: [
    '.....gg....',
    '....gGg....',
    '...ooooo...',
    '..oOOoooo..',
    '.oOoooooOo.',
    '.ooooooooo.',
    '.ooooooooo.',
    '.ooooooooo.',
    '..ooooooo..',
    '...ooooo...',
  ],
  FruitType.apple: [
    '.....b.g...',
    '....b.gg...',
    '..rrr.rrr..',
    '.rRRrrrrrr.',
    '.rRrrrrrrr.',
    'rrrrrrrrrrr',
    'rrrrrrrrrrr',
    '.rrrrrrrrr.',
    '.rrrr.rrrr.',
    '..rr...rr..',
  ],
  FruitType.melon: [
    '.....g.....',
    '....gg.....',
    '..ggGggGg..',
    '.gGmgGmgGg.',
    '.ggGgmgGgg.',
    'gGmgGgGgmGg',
    'gmgGgmgGgGg',
    '.gGgmgGmgg.',
    '..ggGgGgg..',
    '...ggggg...',
  ],
  FruitType.grapes: [
    '.....b.....',
    '...ggbgg...',
    '.pP.pP.pP..',
    '.pp.pp.pp..',
    '..pP.pP.pp.',
    '..pp.pp....',
    '...pP.pP...',
    '...pp.pp...',
    '....pP.....',
    '....pp.....',
  ],
  FruitType.bell: [
    '....yyy....',
    '...yYYyy...',
    '..yYyyyyy..',
    '..yYyyyyy..',
    '..yYyyyyy..',
    '.yYyyyyyyy.',
    '.yyyyyyyyy.',
    'yyyyyyyyyyy',
    'yyyyyyyyyyy',
    '....cccc...',
  ],
  FruitType.key: [
    '...ccccc...',
    '..cc...cc..',
    '..c.....c..',
    '..cc...cc..',
    '...ccccc...',
    '.....c.....',
    '.....cc....',
    '.....c.....',
    '.....cc....',
    '.....c.....',
  ],
};

/// Glow colour of a fruit in the 3D views and on the minimap.
Color fruitColor(FruitType t) => switch (t) {
  FruitType.cherry => _fruitInk['r']!,
  FruitType.strawberry => const Color(0xFFFF4060),
  FruitType.orange => _fruitInk['o']!,
  FruitType.apple => _fruitInk['r']!,
  FruitType.melon => _fruitInk['G']!,
  FruitType.grapes => _fruitInk['p']!,
  FruitType.bell => _fruitInk['y']!,
  FruitType.key => _fruitInk['c']!,
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
