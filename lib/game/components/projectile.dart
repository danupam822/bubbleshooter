import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game_constants.dart';
import '../bubble_shooter_game.dart';
import 'bubble.dart';

// ─────────────────────────────────────────────────────────────────
//  Cached lion-projectile paints — built once, zero per-frame allocs
// ─────────────────────────────────────────────────────────────────
class _LionProjectilePaints {
  // Orbit particles — two paints reused (color alpha updated each frame)
  final Paint orbitOrange = Paint()..color = const Color(0xC8FF4400);
  final Paint orbitYellow = Paint()..color = const Color(0xC8FFAA00);
  // Inner bright spark — alpha updated per frame
  final Paint orbitSpark  = Paint()..color = Colors.white.withAlpha(160);
  // Outer glow — uses blur (one instance, alpha updated)
  final Paint outerGlow   = Paint()
    ..color = const Color(0x50FF6600)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
  // Body, edge, highlight — shader assigned in-place each frame
  final Paint body      = Paint();
  final Paint edge      = Paint();
  final Paint highlight = Paint();
}
final _LionProjectilePaints _lionProjPaints = _LionProjectilePaints();

// ─────────────────────────────────────────────────────────────────
//  Cached TextPainter for lion emoji on projectile
//  Shared with shooter.dart via the same top-level cache in shooter.dart
//  but projectile is a separate compile unit, so we keep its own cache.
// ─────────────────────────────────────────────────────────────────
TextPainter? _cachedProjLionPainter;
double _cachedProjLionFontSize = -1;
TextPainter _getProjLionPainter(double fontSize) {
  if ((fontSize - _cachedProjLionFontSize).abs() > 0.5) {
    _cachedProjLionFontSize = fontSize;
    _cachedProjLionPainter = TextPainter(
      text: TextSpan(
        text: '🦁',
        style: TextStyle(fontSize: fontSize, fontFamily: 'sans-serif'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }
  return _cachedProjLionPainter!;
}

class Projectile extends PositionComponent
    with CollisionCallbacks, HasPaint, HasGameReference<BubbleShooterGame> {
  Vector2 velocity;
  final Color color;
  bool isSnapped = false;

  // Animation timer for lion fire effect
  double _time = 0;

  bool get _isLion => color == superPowerColor;

  Projectile({
    required Vector2 position,
    required Vector2 direction,
    required this.color,
  })  : velocity = direction * 1600,
        super(
          size: Vector2.all(bubbleRadius * 2),
          position: position,
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox(
        radius: bubbleRadius * 0.88,
        anchor: Anchor.center,
        position: size / 2));
  }

  @override
  void render(Canvas canvas) {
    if (_isLion) {
      _drawLionProjectile(canvas, bubbleRadius * 1.05);
    } else {
      drawGlossyBubble(canvas, size.x / 2, color, bubbleRadius * 0.95,
          opacity: opacity, drawGlow: true);
    }
  }

  void _drawLionProjectile(Canvas canvas, double r) {
    final pulse = 0.65 + 0.35 * math.sin(_time * 8.0);
    final center = Offset(r, r);

    // ── Fire orbit particles ─────────────────────────────────────
    // Use two cached paints, update alpha only (no new Paint() per loop)
    final orbitAlpha = (200 * pulse).toInt();
    final sparkAlpha = (160 * pulse).toInt();
    _lionProjPaints.orbitOrange.color = const Color(0xFFFF4400).withAlpha(orbitAlpha);
    _lionProjPaints.orbitYellow.color = const Color(0xFFFFAA00).withAlpha(orbitAlpha);
    _lionProjPaints.orbitSpark.color  = Colors.white.withAlpha(sparkAlpha);

    for (int i = 0; i < 10; i++) {
      final angle = (i / 10) * math.pi * 2 + _time * 3.5;
      final dist = r * (0.92 + 0.28 * math.sin(_time * 4.5 + i * 0.9));
      final px = center.dx + math.cos(angle) * dist;
      final py = center.dy + math.sin(angle) * dist;
      final sz = r * 0.22 * pulse;
      // Alternate between two cached paints — no new Paint() ever allocated
      final paint = (i < 5) ? _lionProjPaints.orbitOrange : _lionProjPaints.orbitYellow;
      canvas.drawCircle(Offset(px, py), sz, paint);
      // Bright inner spark (no MaskFilter.blur to avoid GC pressure)
      canvas.drawCircle(Offset(px, py), sz * 0.45, _lionProjPaints.orbitSpark);
    }

    // ── Outer glow aura (single blur, reused paint) ───────────────
    _lionProjPaints.outerGlow.color =
        const Color(0xFFFF6600).withAlpha((80 * pulse).toInt());
    canvas.drawCircle(center, r * 1.32, _lionProjPaints.outerGlow);

    // ── Golden-orange bubble body ─────────────────────────────────
    final bodyRect = Rect.fromCircle(center: center, radius: r);
    _lionProjPaints.body.shader = const RadialGradient(
      center: Alignment(0.25, 0.28),
      colors: [Color(0xFFFFD060), Color(0xFFFF8800), Color(0xFFCC3300)],
      stops: [0.0, 0.52, 1.0],
    ).createShader(bodyRect);
    canvas.drawCircle(center, r, _lionProjPaints.body);

    // Edge darkening
    _lionProjPaints.edge.shader = const RadialGradient(
      center: Alignment.center,
      colors: [Colors.transparent, Color(0x66000000)],
      stops: [0.6, 1.0],
    ).createShader(bodyRect);
    canvas.drawCircle(center, r, _lionProjPaints.edge);

    // Highlight
    final hOff = Offset(center.dx - r * 0.22, center.dy - r * 0.22);
    final hRect = Rect.fromCircle(center: hOff, radius: r * 0.36);
    _lionProjPaints.highlight.shader = const RadialGradient(
      center: Alignment.center,
      colors: [Color(0xAAFFFFFF), Colors.transparent],
    ).createShader(hRect);
    canvas.drawCircle(hOff, r * 0.36, _lionProjPaints.highlight);

    // ── Lion 🦁 emoji — cached TextPainter ───────────────────────
    final scale = 0.95 + 0.05 * math.sin(_time * 6.0);
    final fontSize = r * 1.25 * scale;
    final tp = _getProjLionPainter(fontSize);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  void update(double dt) {
    if (isSnapped) return;
    super.update(dt);
    _time += dt;
    position += velocity * dt;

    // Wall bounce
    if (position.x < bubbleRadius) {
      position.x = bubbleRadius;
      velocity.x = velocity.x.abs();
    } else if (position.x > game.size.x - bubbleRadius) {
      position.x = game.size.x - bubbleRadius;
      velocity.x = -velocity.x.abs();
    }

    // Ceiling snap
    if (position.y < bubbleRadius + gridTopPadding) {
      position.y = bubbleRadius + gridTopPadding;
      game.snapProjectile(this);
      return;
    }

    // Safety: fell off screen
    if (position.y > game.size.y + bubbleRadius * 2) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (isSnapped) return;
    if (other is Bubble) {
      game.snapProjectile(this, hitComponent: other);
    }
  }
}
