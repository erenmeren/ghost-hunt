import 'dart:math' as math;
import 'dart:ui';

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

/// Arcade style ghost filling a square of side 2r around [center].
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
}) {
  final left = center.dx - r, right = center.dx + r;
  final top = center.dy - r, bottom = center.dy + r;
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
    c.drawPath(body, Paint()..color = bodyColor.withValues(alpha: alpha));
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
