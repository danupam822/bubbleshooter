import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game_constants.dart';
import '../bubble_shooter_game.dart';

class AimLine extends Component with HasGameReference<BubbleShooterGame> {
  Vector2 direction = Vector2(0, -1);
  double _animTime = 0;

  static const double _dotSpacing = 24.0;
  static const double _dotRadius = 3.2;

  // Per-color paint cache to avoid allocations
  Color? _lastColor;
  Paint _dotPaint = Paint()..color = Colors.white;

  @override
  void update(double dt) {
    _animTime += dt;
  }

  @override
  void render(Canvas canvas) {
   final s = game.shooter;
    if (s == null || !s.canShoot) return;
    
    final nextColor = s.nextColor;
    
    // Rebuild paint only if color changed
    if (_lastColor != nextColor) {
      _lastColor = nextColor;
      _dotPaint = Paint()..color = nextColor.withAlpha(200);
    }

    final animOffset = (_animTime * 90) % _dotSpacing;

    // Use targetAngle for dots so they are perfectly instant, 
    // while the barrel has a slight smooth lag
    final double targetAngle = s.targetAngle;
    final Vector2 currentDir = Vector2(math.sin(targetAngle), -math.cos(targetAngle));

    // Start dots from the visual barrel tip (approx distance 56)
    final Vector2 tipOffset = Vector2(math.sin(targetAngle) * 56, -math.cos(targetAngle) * 56);
    Vector2 currentPos = s.position + tipOffset;

    for (int bounce = 0; bounce < 3; bounce++) {
      double t;
      bool hitWall = false;

      if (currentDir.x > 0) {
        t = (game.size.x - bubbleRadius - currentPos.x) / currentDir.x;
        hitWall = true;
      } else if (currentDir.x < 0) {
        t = (bubbleRadius - currentPos.x) / currentDir.x;
        hitWall = true;
      } else {
        t = 2000.0;
      }

      final double tTop =
          (gridTopPadding + bubbleRadius - currentPos.y) / currentDir.y;
      if (tTop > 0 && tTop < t) {
        t = tTop;
        hitWall = false;
      }

      // Draw dots — segment length capped for perf
      double i = animOffset;
      final segLen = t.clamp(0.0, 700.0);
      bool hitBubble = false;

      while (i < segLen) {
        final pos = currentPos + currentDir * i;
        
        // ── GRID COLLISION PREDICTION ───────────────────────────
        final gp = game.getGridPosition(pos);
        if (game.grid[gp.x][gp.y] != null) {
          hitBubble = true;
          break;
        }

        final fade = (1.0 - (i / 650).clamp(0.0, 1.0));
        if (fade < 0.05) break;

        final phaseFrac = (i / _dotSpacing) - (i / _dotSpacing).floor();
        final sz = _dotRadius * (0.78 + 0.22 * math.sin(phaseFrac * math.pi));

        _dotPaint.color = nextColor.withAlpha((210 * fade).toInt());
        canvas.drawCircle(pos.toOffset(), sz, _dotPaint);
        i += _dotSpacing;
      }

      if (hitBubble) break;

      if (hitWall) {
        final bp = (currentPos + currentDir * t).toOffset();
        canvas.drawCircle(bp, 5, Paint()..color = nextColor.withAlpha(160));
        canvas.drawCircle(bp, 2.5, Paint()..color = Colors.white.withAlpha(200));

        currentPos = currentPos + currentDir * t;
        currentDir.x = -currentDir.x; 
      } else {
        break;
      }
    }
  }
}
