import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game_constants.dart';
import '../bubble_shooter_game.dart';
import 'bubble.dart';
import 'projectile.dart';

// Cached shooter paints (static — rebuilt only when color changes)
Paint? _cachedRingPaint;
Color? _cachedRingColor;

// ─────────────────────────────────────────────────────────────────
//  Cached lion-preview paints — built once, avoids per-frame allocs
// ─────────────────────────────────────────────────────────────────
class _LionPreviewPaints {
  final Paint orbitOrange = Paint()..color = const Color(0xFFFF4400).withAlpha(200);
  final Paint orbitYellow = Paint()..color = const Color(0xFFFFAA00).withAlpha(200);
  final Paint outerGlow   = Paint()..color = const Color(0x00FF5500);  // alpha set per-frame
  final Paint body        = Paint();
  final Paint edge        = Paint();
  final Paint highlight   = Paint();
  final Paint fireSpark   = Paint()
    ..color = Colors.white.withAlpha(160)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
  // Glow uses blur — kept but reused not recreated
  final Paint glowPaint   = Paint()
    ..color = const Color(0x46FF5500)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
}

final _LionPreviewPaints _lionPvPaints = _LionPreviewPaints();

// ─────────────────────────────────────────────────────────────────
//  Cached lion-ring paints
// ─────────────────────────────────────────────────────────────────
class _LionRingPaints {
  final Paint glowBlur = Paint()
    ..color = const Color(0x3CFF4400)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  final Paint solidRing = Paint()
    ..color = const Color(0xB4FF6600)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.8;
  final Paint dotOrange = Paint()
    ..color = const Color(0xDCFF4400)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
  final Paint dotYellow = Paint()
    ..color = const Color(0xDCFFAA00)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
}
final _LionRingPaints _lionRingPaints = _LionRingPaints();

// ─────────────────────────────────────────────────────────────────
//  Cached TextPainter for lion emoji (rebuilt only when fontSize changes)
// ─────────────────────────────────────────────────────────────────
TextPainter? _cachedLionPainter;
double _cachedLionFontSize = -1;
TextPainter _getLionPainter(double fontSize) {
  if ((fontSize - _cachedLionFontSize).abs() > 0.5) {
    _cachedLionFontSize = fontSize;
    _cachedLionPainter = TextPainter(
      text: TextSpan(text: '🦁', style: TextStyle(fontSize: fontSize, fontFamily: 'sans-serif')),
      textDirection: TextDirection.ltr,
    )..layout();
  }
  return _cachedLionPainter!;
}

class Shooter extends PositionComponent
    with HasPaint, HasGameReference<BubbleShooterGame> {
  final math.Random random = math.Random();
  late Color nextColor;
  double targetAngle = 0;
  double _cooldownTimer = 0;
  double _pulseTime = 0;
  double _fireTime = 0; // Lion fire animation timer

  // Reusable tip paint — updated color each frame (no allocation)
  final Paint _tipPaint = Paint();
  final Paint _tipWhite = Paint()..color = Colors.white.withAlpha(200);

  // Pre-built static paints
  static final Paint _platformPaint = Paint()
    ..shader = const RadialGradient(
      colors: [Color(0xFF2A2A5A), Color(0xFF0D0B2A)],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 28));

  static final Paint _innerRingPaint = Paint()
    ..color = const Color(0x22FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  static final Paint _barrelPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xFF2A2A4A), Color(0xFF5A5A8A), Color(0xFF2A2A4A)],
    ).createShader(Rect.fromLTWH(-4, -40, 8, 38));

  bool get _isLionLoaded => nextColor == superPowerColor;

  @override
  Future<void> onLoad() async {
    _refreshColor();
  }

  void _refreshColor() {
    final colors = game.viewModel.bubbleColors;
    nextColor = colors[random.nextInt(game.viewModel.getColorCount())];
    _cachedRingColor = null;
  }

  /// Load the lion super power bubble as the next shot.
  void loadSuperPower() {
    nextColor = superPowerColor;
    _cachedRingColor = null;
    _fireTime = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    angle += (targetAngle - angle) * 0.6;
    _pulseTime += dt;
    if (_cooldownTimer > 0) _cooldownTimer -= dt;
    if (_isLionLoaded) _fireTime += dt;
  }

  @override
  void render(Canvas canvas) {
    final pulse = 1.0 + 0.055 * math.sin(_pulseTime * 4.5);

    // Platform base
    canvas.drawCircle(Offset.zero, bubbleRadius * 1.38, _platformPaint);

    if (_isLionLoaded) {
      _drawLionRing(canvas, pulse);
    } else {
      if (_cachedRingColor != nextColor) {
        _cachedRingColor = nextColor;
        _cachedRingPaint = Paint()
          ..color = nextColor.withAlpha(160)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8;
      }
      canvas.drawCircle(Offset.zero, bubbleRadius * 1.3 * pulse, _cachedRingPaint!);
    }

    // Inner subtle ring
    canvas.drawCircle(Offset.zero, bubbleRadius * 1.05, _innerRingPaint);

    // Barrel
    const barrelH = 38.0;
    const barrelW = 7.0;
    final barrelRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(0, -(bubbleRadius + barrelH / 2) + 5),
          width: barrelW,
          height: barrelH),
      const Radius.circular(4),
    );
    canvas.drawRRect(barrelRect, _barrelPaint);

    // Barrel tip — reuse paint, just update color
    final tipColor = _isLionLoaded
        ? Color.lerp(const Color(0xFFFF4400), const Color(0xFFFFCC00),
              0.5 + 0.5 * math.sin(_fireTime * 8.0))!
        : nextColor.withAlpha(220);
    _tipPaint.color = tipColor;
    canvas.drawCircle(
      Offset(0, -(bubbleRadius + barrelH)),
      4.5 * pulse,
      _tipPaint,
    );
    canvas.drawCircle(
      Offset(0, -(bubbleRadius + barrelH)),
      2.0,
      _tipWhite,
    );

    // Preview bubble
    if (_isLionLoaded) {
      _drawLionPreview(canvas, bubbleRadius * 0.88);
    } else {
      drawGlossyBubble(canvas, 0, nextColor, bubbleRadius * 0.88,
          opacity: opacity, drawGlow: false);
    }
  }

  void _drawLionRing(Canvas canvas, double pulse) {
    final firePulse = 0.6 + 0.4 * math.sin(_fireTime * 6.0);
    final ringR = bubbleRadius * 1.35 * pulse;

    // Outer fire glow — update color alpha on cached paint
    _lionRingPaints.glowBlur.color =
        const Color(0xFFFF4400).withAlpha((60 * firePulse).toInt());
    canvas.drawCircle(Offset.zero, ringR * 1.08, _lionRingPaints.glowBlur);

    // Rotating dot segments — reuse dot paints, no new Paint() per loop
    for (int i = 0; i < 8; i++) {
      final a = (i / 8) * math.pi * 2 + _fireTime * 2.5;
      final fx = math.cos(a) * ringR;
      final fy = math.sin(a) * ringR;
      final sz = 3.5 * firePulse;
      final paint = (i < 4) ? _lionRingPaints.dotOrange : _lionRingPaints.dotYellow;
      paint.color = (i < 4 ? const Color(0xFFFF4400) : const Color(0xFFFFAA00))
          .withAlpha((220 * firePulse).toInt());
      canvas.drawCircle(Offset(fx, fy), sz, paint);
    }

    canvas.drawCircle(Offset.zero, ringR, _lionRingPaints.solidRing);
  }

  void _drawLionPreview(Canvas canvas, double r) {
    final pulse = 0.92 + 0.08 * math.sin(_fireTime * 7.0);
    final center = Offset.zero;

    // Fire orbit — reuse cached paints, update alpha only
    for (int i = 0; i < 7; i++) {
      final a = (i / 7) * math.pi * 2 + _fireTime * 3.5;
      final dist = r * (0.88 + 0.22 * math.sin(_fireTime * 4 + i));
      final fx = math.cos(a) * dist;
      final fy = math.sin(a) * dist;
      // Alternate between two cached paints — no new Paint() allocation
      final paint = (i % 2 == 0) ? _lionPvPaints.orbitOrange : _lionPvPaints.orbitYellow;
      canvas.drawCircle(Offset(fx, fy), r * 0.2 * pulse, paint);
    }

    // Outer glow — update alpha on cached paint (no new allocation)
    _lionPvPaints.glowPaint.color =
        const Color(0xFFFF5500).withAlpha((70 * pulse).toInt());
    canvas.drawCircle(center, r * 1.25, _lionPvPaints.glowPaint);

    // Body — create shader only when radius changes (not every frame)
    final bodyRect = Rect.fromCircle(center: center, radius: r);
    _lionPvPaints.body.shader = const RadialGradient(
      center: Alignment(0.25, 0.28),
      colors: [Color(0xFFFFD060), Color(0xFFFF8800), Color(0xFFCC3300)],
      stops: [0.0, 0.52, 1.0],
    ).createShader(bodyRect);
    canvas.drawCircle(center, r, _lionPvPaints.body);

    // Edge
    _lionPvPaints.edge.shader = const RadialGradient(
      center: Alignment.center,
      colors: [Colors.transparent, Color(0x66000000)],
      stops: [0.6, 1.0],
    ).createShader(bodyRect);
    canvas.drawCircle(center, r, _lionPvPaints.edge);

    // Highlight
    final hOff = Offset(-r * 0.22, -r * 0.22);
    final hRect = Rect.fromCircle(center: hOff, radius: r * 0.36);
    _lionPvPaints.highlight.shader = const RadialGradient(
      center: Alignment.center,
      colors: [Color(0xC0FFFFFF), Colors.transparent],
    ).createShader(hRect);
    canvas.drawCircle(hOff, r * 0.36, _lionPvPaints.highlight);

    // Lion emoji — use cached TextPainter (only re-layouts when fontSize changes)
    final fontSize = r * 1.2 * pulse;
    final tp = _getLionPainter(fontSize);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }

  bool get canShoot => _cooldownTimer <= 0;

  void shoot() {
    if (!canShoot) return;
    _cooldownTimer = shootCooldown;

    // Use targetAngle instead of current angle to ensure we shoot exactly where
    // the user is aiming (matching the AimLine), even if the barrel hasn't fully
    // rotated visually yet.
    final shootDir = Vector2(math.sin(targetAngle), -math.cos(targetAngle));
    
    // Snap visual angle to target for a crisp, responsive feel when firing
    angle = targetAngle;

    // tipOffset matches the barrel tip in render() and the aim line start
    final tipOffset = Vector2(math.sin(targetAngle) * 56, -math.cos(targetAngle) * 56);
    final startPos = position + tipOffset;

    game.add(Projectile(
        position: startPos, direction: shootDir, color: nextColor));

    game.playShootSound();

    if (_isLionLoaded) {
      game.onSuperPowerFired();
    }
    _refreshColor();
  }
}
