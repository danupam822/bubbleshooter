import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import '../game_constants.dart';

// ─────────────────────────────────────────────────────────────────
// Super power sentinel color — never used as a normal bubble color
// ─────────────────────────────────────────────────────────────────
const Color superPowerColor = Color(0xFFFFAA00);

// ─────────────────────────────────────────────────────────────────
// Per-color paint cache — built ONCE, reused every frame
// ─────────────────────────────────────────────────────────────────
final Map<Color, _BubblePaints> _paintCache = {};

class _BubblePaints {
  final Paint body;
  final Paint edge;
  final Paint glow1;
  final Paint glow2;
  final Paint highlight;
  final Paint spec;
  final Paint rim;

  _BubblePaints(this.body, this.edge, this.glow1, this.glow2,
      this.highlight, this.spec, this.rim);
}

_BubblePaints _buildPaints(Color color, double r) {
  final center = Offset(r, r);
  final lighter = _lighten(color, 0.28);
  final darker = _darken(color, 0.3);
  final hOffset = Offset(center.dx - r * 0.22, center.dy - r * 0.22);

  // Fake glow: two larger transparent circles (NO blur)
  final g1 = Paint()
    ..color = color.withAlpha(55)
    ..style = PaintingStyle.fill;
  final g2 = Paint()
    ..color = color.withAlpha(28)
    ..style = PaintingStyle.fill;

  final body = Paint()
    ..shader = RadialGradient(
      center: const Alignment(0.28, 0.32),
      colors: [lighter, color, darker],
      stops: const [0.0, 0.52, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: r));

  final edge = Paint()
    ..shader = RadialGradient(
      center: Alignment.center,
      colors: [Colors.transparent, const Color(0x55000000)],
      stops: const [0.6, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: r));

  final highlight = Paint()
    ..shader = RadialGradient(
      center: Alignment.center,
      colors: [const Color(0xD8FFFFFF), Colors.transparent],
    ).createShader(Rect.fromCircle(center: hOffset, radius: r * 0.4));

  final spec = Paint()..color = const Color(0x99FFFFFF);

  final rim = Paint()
    ..color = const Color(0x40FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;

  return _BubblePaints(body, edge, g1, g2, highlight, spec, rim);
}

_BubblePaints _getPaints(Color color, double r) =>
    _paintCache.putIfAbsent(color, () => _buildPaints(color, r));

// ─────────────────────────────────────────────────────────────────
// Bubble component
// ─────────────────────────────────────────────────────────────────
class Bubble extends PositionComponent with CollisionCallbacks, HasPaint {
  final Color color;
  int gridRow;
  int gridCol;
  final bool isBomb;
  final bool isSuperPower;
  final String? emoji;

  // Bomb idle animation timer
  double _bombPulseTime = 0;
  // Slight cosmetic bob offset (does NOT change grid pos)
  double _bobOffset = 0;
  // Rainbow hue time for super power
  double _rainbowTime = 0;

  Bubble({
    required this.color,
    required Vector2 position,
    required this.gridRow,
    required this.gridCol,
    this.isBomb = false,
    this.isSuperPower = false,
    this.emoji,
  }) : super(
          size: Vector2.all(bubbleRadius * 2),
          position: position,
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox(
        radius: bubbleRadius * 0.95,
        anchor: Anchor.center,
        position: size / 2));

    if (isSuperPower) {
      // Crown emoji on super power bubble
      final crown = TextComponent(
        text: '⚡',
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: bubbleRadius * 1.1,
            shadows: const [
              Shadow(color: Colors.black45, offset: Offset(1, 1), blurRadius: 3)
            ],
          ),
        ),
        position: size / 2,
        anchor: Anchor.center,
      );
      add(crown);
      // Breathe + spin
      crown.add(ScaleEffect.to(
        Vector2.all(1.2),
        EffectController(duration: 0.7, reverseDuration: 0.7, infinite: true, curve: Curves.easeInOut),
      ));
      crown.add(RotateEffect.by(
        math.pi * 2,
        EffectController(duration: 3.0, infinite: true),
      ));
    } else if (emoji != null) {
      final emojiComp = TextComponent(
        text: emoji,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: bubbleRadius * 1.1,
            shadows: const [
              Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2)
            ],
          ),
        ),
        position: size / 2,
        anchor: Anchor.center,
      );
      add(emojiComp);

      // ── "Live" Animations ──────────────────────────────────────
      // Breathing/Pulse effect
      emojiComp.add(ScaleEffect.to(
        Vector2.all(1.15),
        EffectController(
          duration: 0.8 + math.Random().nextDouble() * 0.4,
          reverseDuration: 0.8,
          infinite: true,
          curve: Curves.easeInOut,
        ),
      ));
      
      // Subtle rotation sway
      emojiComp.add(RotateEffect.by(
        0.1,
        EffectController(
          duration: 1.5 + math.Random().nextDouble(),
          reverseDuration: 1.5,
          infinite: true,
          curve: Curves.easeInOut,
        ),
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isBomb) {
      _bombPulseTime += dt;
      // Cosmetic bob — visual only, does NOT change gridRow/gridCol
      _bobOffset = math.sin(_bombPulseTime * 3.2) * 1.4;
    }
    if (isSuperPower) {
      _rainbowTime += dt;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (isBomb) {
      _drawBomb(canvas, bubbleRadius, opacity: opacity);
    } else if (isSuperPower) {
      _drawSuperPower(canvas, bubbleRadius, opacity: opacity);
    } else {
      drawGlossyBubble(canvas, bubbleRadius, color, bubbleRadius,
          opacity: opacity, drawGlow: false);
      // Emoji is handled by animated child component
    }
  }

  void _drawBomb(Canvas canvas, double r, {double opacity = 1.0}) {
    final alpha = (opacity * 255).toInt();
    // Bob offset — shift the whole drawing down/up
    final center = Offset(r, r + _bobOffset);

    // ── Fuse (curved line from top of sphere) ──
    final fusePaint = Paint()
      ..color = Color.fromARGB(alpha, 139, 90, 43)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fuseStart = center - Offset(0, r * 0.9);
    final fuseEnd = center - Offset(r * 0.35, r * 1.55);
    final fusePath = Path()
      ..moveTo(fuseStart.dx, fuseStart.dy)
      ..cubicTo(
        fuseStart.dx + r * 0.1, fuseStart.dy - r * 0.2,
        fuseEnd.dx + r * 0.2, fuseEnd.dy + r * 0.2,
        fuseEnd.dx, fuseEnd.dy,
      );
    canvas.drawPath(fusePath, fusePaint);

    // ── Fuse tip spark — glowing dot that pulses ──
    final sparkPulse = 0.6 + 0.4 * math.sin(_bombPulseTime * 6.5);
    final sparkColor1 = Color.fromARGB((alpha * sparkPulse).toInt(), 255, 200, 50);
    final sparkColor2 = Color.fromARGB((alpha * sparkPulse * 0.6).toInt(), 255, 100, 20);
    canvas.drawCircle(fuseEnd, r * 0.18 * sparkPulse,
        Paint()..color = sparkColor2..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(fuseEnd, r * 0.09 * sparkPulse,
        Paint()..color = sparkColor1);

    // ── Bomb body (glossy dark sphere) ──
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.3, 0.3),
        colors: [
          Color.fromARGB(alpha, 72, 72, 82),
          Color.fromARGB(alpha, 18, 18, 22),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bodyPaint);

    // Rim shadow
    canvas.drawCircle(center, r,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            colors: [Colors.transparent, Color.fromARGB((alpha * 0.6).toInt(), 0, 0, 0)],
            stops: const [0.55, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: r)));

    // Highlight
    canvas.drawCircle(
      center - Offset(r * 0.22, r * 0.24),
      r * 0.36,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            Color.fromARGB((alpha * 0.45).toInt(), 255, 255, 255),
            Colors.transparent,
          ],
          stops: const [0.0, 0.75],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    // Small white specular dot
    canvas.drawCircle(
      center - Offset(r * 0.34, r * 0.38),
      r * 0.09,
      Paint()..color = Color.fromARGB((alpha * 0.7).toInt(), 255, 255, 255),
    );

    // ── Danger ring — pulsing orange glow around body ──
    final ringPulse = 0.4 + 0.6 * math.sin(_bombPulseTime * 4.0);
    canvas.drawCircle(
      center,
      r * 1.12,
      Paint()
        ..color = Color.fromARGB((alpha * ringPulse * 0.55).toInt(), 255, 100, 0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  void _drawSuperPower(Canvas canvas, double r, {double opacity = 1.0}) {
    final alpha = (opacity * 255).toInt();
    final center = Offset(r, r);

    // Rainbow hue shift
    final hue = (_rainbowTime * 80) % 360;
    final rainbowColor = HSVColor.fromAHSV(1.0, hue, 0.85, 1.0).toColor();
    final rainbowColor2 = HSVColor.fromAHSV(1.0, (hue + 120) % 360, 0.85, 1.0).toColor();
    final rainbowColor3 = HSVColor.fromAHSV(1.0, (hue + 240) % 360, 0.85, 1.0).toColor();

    // Outer rainbow glow ring
    final glowPulse = 0.5 + 0.5 * math.sin(_rainbowTime * 5.0);
    canvas.drawCircle(
      center, r * 1.38,
      Paint()
        ..shader = SweepGradient(
          colors: [rainbowColor, rainbowColor2, rainbowColor3, rainbowColor],
          startAngle: _rainbowTime * 2.0,
          endAngle: _rainbowTime * 2.0 + math.pi * 2,
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.38))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * glowPulse),
    );

    // Golden body
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.25, 0.28),
        colors: [
          Color.fromARGB(alpha, 255, 235, 120),
          Color.fromARGB(alpha, 230, 160, 20),
          Color.fromARGB(alpha, 180, 100, 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bodyPaint);

    // Edge darkening
    canvas.drawCircle(center, r,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            colors: [Colors.transparent, const Color(0x55000000)],
            stops: const [0.6, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: r)));

    // Highlight
    final hOff = Offset(center.dx - r * 0.22, center.dy - r * 0.22);
    canvas.drawCircle(hOff, r * 0.38,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            colors: [
              Color.fromARGB((alpha * 0.85).toInt(), 255, 255, 255),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: hOff, radius: r * 0.38)));

    // Specular
    canvas.drawCircle(
      center - Offset(r * 0.35, r * 0.42), r * 0.1,
      Paint()..color = Color.fromARGB((alpha * 0.6).toInt(), 255, 255, 255),
    );

    // Rim
    final rimPath = Path()
      ..addArc(Rect.fromCircle(center: center, radius: r - 1.5),
          math.pi * 0.55, math.pi * 0.55);
    canvas.drawPath(
      rimPath,
      Paint()
        ..color = Color.fromARGB((alpha * 0.4).toInt(), 255, 255, 255)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Glossy bubble — optimized, no blur
// ─────────────────────────────────────────────────────────────────
void drawGlossyBubble(
    Canvas canvas, double centerPos, Color color, double r,
    {double opacity = 1.0, bool drawGlow = false}) {
  final center = Offset(centerPos, centerPos);
  final p = _getPaints(color, r);

  void drawBubble() {
    // Fake glow rings (cheap — just two circles, no blur)
    if (drawGlow) {
      canvas.drawCircle(center, r * 1.35, p.glow2);
      canvas.drawCircle(center, r * 1.18, p.glow1);
    }
    canvas.drawCircle(center, r, p.body);
    canvas.drawCircle(center, r, p.edge);
    final hOff = Offset(center.dx - r * 0.22, center.dy - r * 0.22);
    canvas.drawCircle(hOff, r * 0.38, p.highlight);
    canvas.drawCircle(center - Offset(r * 0.35, r * 0.42), r * 0.1, p.spec);
    final rimPath = Path()
      ..addArc(Rect.fromCircle(center: center, radius: r - 1.5),
          math.pi * 0.55, math.pi * 0.55);
    canvas.drawPath(rimPath, p.rim);
  }

  if (opacity >= 0.999) {
    drawBubble();
  } else {
    canvas.saveLayer(
      Rect.fromCircle(center: center, radius: r + 10),
      Paint()..color = Color.fromARGB((opacity * 255).toInt(), 255, 255, 255),
    );
    drawBubble();
    canvas.restore();
  }
}

Color _lighten(Color c, double a) =>
    HSLColor.fromColor(c).withLightness((HSLColor.fromColor(c).lightness + a).clamp(0, 1)).toColor();

Color _darken(Color c, double a) =>
    HSLColor.fromColor(c).withLightness((HSLColor.fromColor(c).lightness - a).clamp(0, 1)).toColor();
