import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../viewmodels/game_viewmodel.dart';
import '../services/ad_service.dart';
import 'game_constants.dart';
import 'components/bubble.dart';
import 'components/shooter.dart';
import 'components/aim_line.dart';
import 'components/projectile.dart';

// ─────────────────────────────────────────────────────────────────
//  Background starfield
// ─────────────────────────────────────────────────────────────────
class _StarfieldComponent extends Component {
  final List<_Star> stars = [];
  final math.Random _rng = math.Random(42);
  Vector2 gameSize = Vector2.zero();
  double _time = 0;

  void init(Vector2 size) {
    gameSize = size;
    stars.clear();
    for (int i = 0; i < 80; i++) {
      final baseOpacity = _rng.nextDouble() * 0.65 + 0.3;
      stars.add(_Star(
        x: _rng.nextDouble() * size.x,
        y: _rng.nextDouble() * size.y,
        radius: _rng.nextDouble() * 1.7 + 0.4,
        baseOpacity: baseOpacity,
        twinkleSpeed: _rng.nextDouble() * 2.5 + 0.8,
        twinkleOffset: _rng.nextDouble() * math.pi * 2,
        paint: Paint()..color = Colors.white,
      ));
    }
  }

  @override
  void update(double dt) {
    _time += dt;
    for (final star in stars) {
      final twinkle = 0.45 + 0.55 * math.sin(_time * star.twinkleSpeed + star.twinkleOffset);
      star.paint.color = Colors.white.withAlpha((star.baseOpacity * twinkle * 255).toInt());
    }
  }

  @override
  void render(Canvas canvas) {
    for (final star in stars) {
      canvas.drawCircle(Offset(star.x, star.y), star.radius, star.paint);
    }
  }
}

class _Star {
  final double x, y, radius, baseOpacity, twinkleSpeed, twinkleOffset;
  final Paint paint;
  const _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.baseOpacity,
    required this.twinkleSpeed,
    required this.twinkleOffset,
    required this.paint,
  });
}

// ─────────────────────────────────────────────────────────────────
//  Score popup
// ─────────────────────────────────────────────────────────────────
class _ScorePopup extends TextComponent {
  _ScorePopup(String text, Vector2 pos, Color color)
      : super(
          text: text,
          textRenderer: TextPaint(
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 3)
              ],
            ),
          ),
          position: pos,
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(MoveByEffect(
      Vector2(0, -60),
      EffectController(duration: 1.0, curve: Curves.easeOut),
      onComplete: removeFromParent,
    ));
    add(ScaleEffect.to(
      Vector2.all(1.25),
      EffectController(duration: 0.18, reverseDuration: 0.18),
    ));
    add(ScaleEffect.to(
      Vector2.zero(),
      EffectController(duration: 0.25, startDelay: 0.65, curve: Curves.easeIn),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────
//  Ambient nebula background rendering
// ─────────────────────────────────────────────────────────────────
class _BackgroundComponent extends Component {
  @override
  int get priority => -10;

  Vector2 _gameSize = Vector2.zero();
  Picture? _cachedPicture;

  set gameSize(Vector2 size) {
    if (_gameSize != size) {
      _gameSize = size;
      _cachedPicture = null;
    }
  }

  void _createCache() {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, _gameSize.x, _gameSize.y);

    // Deep space gradient
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0A0A1A),
          Color(0xFF0D0B2A),
          Color(0xFF130D1F),
          Color(0xFF0A0A14),
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    // Subtle purple nebula blob
    final nebula1 = Paint()
      ..color = const Color(0xFF4A00A0).withOpacity(0.07)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _gameSize.x * 0.4);
    canvas.drawCircle(
        Offset(_gameSize.x * 0.2, _gameSize.y * 0.3), _gameSize.x * 0.55, nebula1);

    // Subtle teal nebula blob
    final nebula2 = Paint()
      ..color = const Color(0xFF006A8A).withOpacity(0.055)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _gameSize.x * 0.45);
    canvas.drawCircle(
        Offset(_gameSize.x * 0.8, _gameSize.y * 0.6), _gameSize.x * 0.5, nebula2);

    _cachedPicture = recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    if (_gameSize.x <= 0 || _gameSize.y <= 0) {
      // Emergency background if size isn't set yet
      canvas.drawColor(const Color(0xFF0A0A1A), BlendMode.src);
      return;
    }
    if (_cachedPicture == null) {
      _createCache();
    }
    canvas.drawPicture(_cachedPicture!);
  }
}

// ═══════════════════════════════════════════════════════════════════
//  REALISTIC PARTICLE SYSTEM
// ═══════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────
//  Heat Flash — instant bright white-orange radial burst at center
// ─────────────────────────────────────────────────────────────────
class _HeatFlash extends PositionComponent {
  double _timer = 0;
  final double radius;
  final Color flashColor;
  final Paint _paint = Paint();

  _HeatFlash({required Vector2 position, required this.radius, required this.flashColor})
      : super(position: position, anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    if (_timer >= 0.12) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    // Fast fade: bright at 0ms, gone at 120ms
    final progress = (_timer / 0.12).clamp(0.0, 1.0);
    // Ease-out flash curve
    final alpha = (1.0 - progress * progress) * 0.88;

    final center = Offset.zero;
    final rect = Rect.fromCircle(center: center, radius: radius);

    _paint.shader = RadialGradient(
      colors: [
        Colors.white.withOpacity(alpha),
        flashColor.withOpacity(alpha * 0.6),
        flashColor.withOpacity(alpha * 0.15),
        Colors.transparent,
      ],
      stops: const [0.0, 0.25, 0.6, 1.0],
    ).createShader(rect);

    canvas.drawCircle(center, radius * (1.0 + progress * 0.5), _paint);
  }
}

// ─────────────────────────────────────────────────────────────────
//  Realistic Smoke Particle — Optimized (No expensive blurs)
// ─────────────────────────────────────────────────────────────────
class _RealisticSmokeParticle extends PositionComponent {
  Vector2 velocity;
  final double lifeTime;
  double _timer = 0;
  final double initialRadius;
  final Color coreColor;
  final Color smokeColor;
  final double turbulenceFreq;
  final double turbulenceAmp;
  final double startDelay;
  final double rotationSpeed;
  double _currentAngle = 0;

  final Paint _paint = Paint();

  _RealisticSmokeParticle({
    required Vector2 position,
    required this.velocity,
    required this.coreColor,
    required this.smokeColor,
    required this.initialRadius,
    this.lifeTime = 0.8,
    this.turbulenceFreq = 4.0,
    this.turbulenceAmp = 10.0,
    this.startDelay = 0,
    this.rotationSpeed = 0,
  }) : super(position: position, anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    if (_timer < startDelay) return;

    final t = _timer - startDelay;
    if (t >= lifeTime) {
      removeFromParent();
      return;
    }

    _currentAngle += rotationSpeed * dt;
    final drift = turbulenceAmp * math.sin(t * turbulenceFreq + startDelay * 7.3);
    final perp = Vector2(-velocity.y, velocity.x);
    if (perp.length > 0.01) perp.normalize();

    position += velocity * dt + perp * drift * dt;
    velocity *= math.pow(0.85, dt * 60).toDouble();
  }

  @override
  void render(Canvas canvas) {
    if (_timer < startDelay) return;
    final t = (_timer - startDelay).clamp(0.0, lifeTime);
    final progress = t / lifeTime;

    double alpha = progress < 0.2 ? progress / 0.2 : 1.0 - progress;
    alpha = alpha.clamp(0.0, 1.0);

    final midColor = Color.lerp(coreColor, smokeColor, progress)!;
    final r = initialRadius * (1.0 + progress * 2.5);

    canvas.save();
    canvas.rotate(_currentAngle);

    // Optimized: Use a single RadialGradient instead of multiple layers with blurs
    _paint.shader = RadialGradient(
      colors: [
        midColor.withOpacity(alpha * 0.7),
        smokeColor.withOpacity(alpha * 0.3),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));

    canvas.drawCircle(Offset.zero, r, _paint);
    canvas.restore();
  }
}

// ─────────────────────────────────────────────────────────────────
//  Debris Chunk — solid spinning fragment with gravity
// ─────────────────────────────────────────────────────────────────
class _DebrisChunk extends PositionComponent {
  Vector2 velocity;
  final double lifeTime;
  double _timer = 0;
  double _angle = 0;
  final double _angularVelocity;
  final Color chunkColor;
  final double _size;
  final Paint _paint = Paint();
  final Paint _shadowPaint = Paint();

  _DebrisChunk({
    required Vector2 position,
    required this.velocity,
    required this.chunkColor,
    required double size,
    this.lifeTime = 0.7,
  })  : _size = size,
        _angularVelocity = (math.Random().nextDouble() - 0.5) * 14.0,
        super(position: position, anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    if (_timer >= lifeTime) {
      removeFromParent();
      return;
    }
    velocity.y += 380 * dt; // Gravity
    velocity *= math.pow(0.93, dt * 60).toDouble(); // Drag
    position += velocity * dt;
    _angle += _angularVelocity * dt;
  }

  @override
  void render(Canvas canvas) {
    final progress = (_timer / lifeTime).clamp(0.0, 1.0);
    final alpha = ((1.0 - progress) * 255).toInt();
    if (alpha <= 0) return;

    canvas.save();
    canvas.rotate(_angle);

    // Shadow under the chunk
    _shadowPaint.color = Colors.black.withAlpha((alpha * 0.4).toInt());
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(1.5, 1.5), width: _size, height: _size * 0.7),
        const Radius.circular(1),
      ),
      _shadowPaint,
    );

    // Chunk body — darkened/charred color
    _paint.color = chunkColor.withAlpha(alpha);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: _size, height: _size * 0.7),
        const Radius.circular(1),
      ),
      _paint,
    );

    // Hot edge highlight on freshly-ejected chunks
    if (progress < 0.3) {
      final highlightAlpha = alpha * (1.0 - progress / 0.3) * 0.7;
      final highlightPaint = Paint()
        ..color = Colors.white.withAlpha(highlightAlpha.toInt())
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: _size, height: _size * 0.7),
          const Radius.circular(1),
        ),
        highlightPaint,
      );
    }

    canvas.restore();
  }
}

// ─────────────────────────────────────────────────────────────────
//  Ember Particle — tiny glowing ember that drifts upward
// ─────────────────────────────────────────────────────────────────
class _EmberParticle extends PositionComponent {
  Vector2 velocity;
  final double lifeTime;
  double _timer = 0;
  final Color emberColor;
  final double _radius;
  final Paint _paint = Paint();
  final Paint _glowPaint = Paint();
  final Paint _shellPaint = Paint(); // cached — updated color only
  final double _flickerPhase;
  final double _flickerSpeed;

  _EmberParticle({
    required Vector2 position,
    required this.velocity,
    required this.emberColor,
    required double radius,
    this.lifeTime = 1.4,
  })  : _radius = radius,
        _flickerPhase = math.Random().nextDouble() * math.pi * 2,
        _flickerSpeed = 8.0 + math.Random().nextDouble() * 12.0,
        super(position: position, anchor: Anchor.center) {
    // Set MaskFilter ONCE in constructor — never reassign to avoid per-frame allocs
    _glowPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 2.5);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    if (_timer >= lifeTime) {
      removeFromParent();
      return;
    }
    // Embers drift upward and sway slightly
    velocity.y -= 18 * dt;  // buoyancy
    velocity.x += math.sin(_timer * 3.2 + _flickerPhase) * 12 * dt;
    velocity *= math.pow(0.97, dt * 60).toDouble();
    position += velocity * dt;
  }

  @override
  void render(Canvas canvas) {
    final progress = (_timer / lifeTime).clamp(0.0, 1.0);
    // Ember flickers: fast oscillation
    final flicker = 0.6 + 0.4 * math.sin(_timer * _flickerSpeed + _flickerPhase);
    // Long tail fade
    double alpha = flicker;
    if (progress > 0.5) {
      alpha *= (1.0 - (progress - 0.5) / 0.5);
    }

    // Glow halo — MaskFilter already set in constructor, just update color
    _glowPaint.color = emberColor.withAlpha((alpha * 80).toInt());
    canvas.drawCircle(Offset.zero, _radius * 2.0, _glowPaint);

    // Bright core
    _paint.color = Colors.white.withAlpha((alpha * 220).toInt());
    canvas.drawCircle(Offset.zero, _radius * 0.5, _paint);

    // Colored shell — reuse cached paint, just update color
    _shellPaint.color = emberColor.withAlpha((alpha * 180).toInt());
    canvas.drawCircle(Offset.zero, _radius, _shellPaint);
  }
}

// ─────────────────────────────────────────────────────────────────
//  Hot Spark — high-speed streak with gravity tail
// ─────────────────────────────────────────────────────────────────
class _HotSpark extends PositionComponent {
  Vector2 velocity;
  final double lifeTime;
  double _timer = 0;
  final Color sparkColor;
  final Paint _paint = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8;

  _HotSpark({
    required Vector2 position,
    required this.velocity,
    required this.sparkColor,
    this.lifeTime = 0.5,
  }) : super(position: position, anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    velocity.y += 460 * dt; // Gravity
    velocity *= math.pow(0.955, dt * 60).toDouble();
    position += velocity * dt;
    if (_timer >= lifeTime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final progress = (_timer / lifeTime).clamp(0.0, 1.0);
    final alpha = ((1.0 - progress * progress) * 255).toInt();
    final speed = velocity.length;
    final length = (speed * 0.028).clamp(2.0, 12.0) * (1.0 - progress);
    if (length < 0.5 || velocity.length < 0.1) return;

    final dir = velocity.normalized();
    _paint.color = sparkColor.withAlpha(alpha);

    // Main streak
    canvas.drawLine(
      Offset(-dir.x * length, -dir.y * length),
      Offset.zero,
      _paint,
    );

    // White-hot tip
    final tipPaint = Paint()..color = Colors.white.withAlpha((alpha * 0.9).toInt());
    canvas.drawCircle(Offset.zero, 1.8 * (1 - progress * 0.7), tipPaint);
  }
}

// ─────────────────────────────────────────────────────────────────
//  Super Power award banner (Flame component)
// ─────────────────────────────────────────────────────────────────
class _SuperPowerBanner extends PositionComponent {
  _SuperPowerBanner(Vector2 center) : super(position: center, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Golden glow ring
    add(_GlowRing());
    // Main text
    final txt = TextComponent(
      text: '⚡ SUPER POWER EARNED! ⚡',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFE44D),
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          shadows: [
            Shadow(color: Color(0xFFFFAA00), offset: Offset(0, 0), blurRadius: 12),
            Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 5),
          ],
        ),
      ),
      anchor: Anchor.center,
    );
    add(txt);

    // Bounce in → hold → scale out
    scale = Vector2.all(0.1);
    add(ScaleEffect.to(
      Vector2.all(1.0),
      EffectController(duration: 0.25, curve: Curves.easeOutBack),
    ));
    add(MoveByEffect(
      Vector2(0, -80),
      EffectController(duration: 0.9, startDelay: 0.4, curve: Curves.easeIn),
      onComplete: removeFromParent,
    ));
    add(ScaleEffect.to(
      Vector2.zero(),
      EffectController(duration: 0.2, startDelay: 0.85, curve: Curves.easeIn),
    ));
  }
}

class _GlowRing extends CircleComponent {
  _GlowRing()
      : super(
          radius: 80,
          anchor: Anchor.center,
          paint: Paint()
            ..color = const Color(0x44FFD700)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
}

// ─────────────────────────────────────────────────────────────────
//  Main game class
// ─────────────────────────────────────────────────────────────────
class BubbleShooterGame extends FlameGame
    with HasCollisionDetection, TapCallbacks, DragCallbacks {
  final GameViewModel viewModel;

  /// Called when a level is completed — Flutter overlay listens to this.
  void Function(int level, int bonus)? onLevelComplete;
  
  /// Called when bubbles reach the bottom.
  void Function()? onGameOver;

  Shooter? shooter;
  late AimLine aimLine;
  final List<List<Bubble?>> grid = List.generate(35, (_) => List.filled(10, null));

  double _autoShiftTimer = 0;
  bool _isLevelChanging = false;
  bool _isGameOver = false;
  bool _hasLevelStarted = false;
  bool _isAiming = false;
  Vector2 _lastInputPos = Vector2.zero();

  /// Called by the Flutter HUD — loads lion into shooter (decrements count).
  void activateStoredSuperPower() {
    if (viewModel.useSuperPower()) {
      shooter?.loadSuperPower();
    }
  }

  /// Called by shooter after lion projectile is launched (no-op — blast on snap).
  void onSuperPowerFired() {}

  // ─────────────────────────────────────────────────────────────
  //  LION BLAST — removes N full rows + N full columns (cross/+)
  //  where N = current level
  // ─────────────────────────────────────────────────────────────
  void _lionBlast(int centerRow, int centerCol) {
    final N = viewModel.superPowerBlastSize;
    final half = N ~/ 2;

    final rowStart = (centerRow - half).clamp(0, grid.length - 1);
    final rowEnd   = (rowStart + N - 1).clamp(0, grid.length - 1);
    final colStart = (centerCol - half).clamp(0, grid[0].length - 1);
    final colEnd   = (colStart + N - 1).clamp(0, grid[0].length - 1);

    int popped = 0;

    // Optimized: Collect bubbles to pop first
    final List<Bubble> bubblesToPop = [];

    for (int r = rowStart; r <= rowEnd; r++) {
      for (int c = 0; c < grid[r].length; c++) {
        final b = grid[r][c];
        if (b != null) {
          bubblesToPop.add(b);
          grid[r][c] = null;
        }
      }
    }

    for (int c = colStart; c <= colEnd; c++) {
      for (int r = 0; r < grid.length; r++) {
        if (r >= rowStart && r <= rowEnd) continue;
        final b = grid[r][c];
        if (b != null) {
          bubblesToPop.add(b);
          grid[r][c] = null;
        }
      }
    }

    // Optimized: Pop bubbles with a simple effect if many are popping
    popped = bubblesToPop.length;
    for (final b in bubblesToPop) {
      viewModel.addScore(10, b.color);
      // Only create full burst for first few to save perf
      if (bubblesToPop.indexOf(b) < 15) {
        _popBubble(b);
      } else {
        b.removeFromParent(); // Instant remove for the rest
      }
    }

    final blastCenter = getPositionForGrid(centerRow, centerCol);
    _createRealisticBurst(blastCenter, const Color(0xFFFF4400), isLarge: true);
    playExplosionSound();

    _showLionSweepEffect(rowStart, rowEnd, colStart, colEnd);

    add(_ScorePopup(
      '🦁 LION ROAR! +${popped * 10}',
      blastCenter + Vector2(0, -40),
      const Color(0xFFFF8800),
    ));
  }

  void _showLionSweepEffect(int rStart, int rEnd, int cStart, int cEnd) {
    final rng = math.Random();
    // Simplified sweep: spawn fewer particles across the area
    for (int i = 0; i < 20; i++) {
      final r = rStart + rng.nextInt(rEnd - rStart + 1);
      final c = rng.nextInt(grid[0].length);
      final pos = getPositionForGrid(r, c);
      add(_RealisticSmokeParticle(
        position: pos,
        velocity: Vector2((rng.nextDouble() - 0.5) * 60, -40),
        coreColor: const Color(0xFFFFBB00),
        smokeColor: const Color(0xFF3A2A1A),
        initialRadius: 8,
      ));
    }
  }

  final List<String> animalEmojis = [
    '🐱', '🐶', '🦊', '🐼', '🦁', '🐯', '🐸', '🐵', '🦄', '🦖',
    '🐘', '🦒', '🦓', '🦛', '🦏', '🐊', '🐍', '🦎', '🐢', '🐙',
    '🦑', '🦀', '🐠', '🐬', '🐳', '🦈', '🐧', '🦉', '🦅', '🦜',
    '🦩', '🐔', '🦆', '🦢', '🐝', '🦋', '🐞', '🐌', '🐿️', '🦔',
    '🐇', '🐿️', '🦘', '🦥', '🦦', '🦨', '🦡', '🐺', '🐻', '🐨',
    '🐮', '🐷', '🐭', '🐹', '🐰', '🐻‍❄️', '🐐', '🐑', '🐴', '🫏',
  ];

  late _StarfieldComponent _starfield;
  late _BackgroundComponent _background;

  BubbleShooterGame(this.viewModel);

  // ── Audio pools — pre-allocated, reused, zero channel exhaustion ──
  AudioPool? _shootPool;
  AudioPool? _popPool;
  AudioPool? _explosionPool;
  AudioPool? _faaahPool;
  bool _poolsReady = false;

  Future<void> _loadAudioSafely() async {
    // Small delay so platform channels are ready
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      print('[Audio] Starting audio setup...');

      // 1. Set global audio context
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      ));

      // 2. Preload cache
      await FlameAudio.audioCache.loadAll([
        'shoot.mp3',
        'pop.mp3',
        'explosion.mp3',
        'bgn.mp3',
        'faaah.mp3',
      ]);

      // 3. Build AudioPools — each pool pre-allocates N players and
      //    reuses them round-robin. This prevents Android channel
      //    exhaustion and eliminates per-shot AudioPlayer allocation.
      _shootPool     = await FlameAudio.createPool('shoot.mp3',     maxPlayers: 4);
      _popPool       = await FlameAudio.createPool('pop.mp3',       maxPlayers: 6);
      _explosionPool = await FlameAudio.createPool('explosion.mp3', maxPlayers: 3);
      _faaahPool     = await FlameAudio.createPool('faaah.mp3',     maxPlayers: 3);
      _poolsReady    = true;

      print('[Audio] Pools ready: shoot=4, pop=6, explosion=3, faaah=3');
    } catch (e, stack) {
      print('[Audio] Error during setup: $e');
      print(stack);
    }

    _updateBgmState();
  }

  void _updateBgmState() {
    try {
      if (viewModel.soundEnabled) {
        if (!FlameAudio.bgm.isPlaying) {
          FlameAudio.bgm.play('bgn.mp3', volume: 0.4);
        }
      } else {
        FlameAudio.bgm.stop();
      }
    } catch (e) {
      print('[Audio] BGM update error: $e');
    }
  }

  void playShootSound() {
    if (!viewModel.soundEnabled || !_poolsReady) return;
    try { _shootPool?.start(volume: 0.6); } catch (e) {
      print('[Audio] shoot error: $e');
    }
  }

  void playPopSound() {
    if (!viewModel.soundEnabled || !_poolsReady) return;
    try { _popPool?.start(volume: 0.5); } catch (e) {
      print('[Audio] pop error: $e');
    }
  }

  void playFaaahSound() {
    if (!viewModel.soundEnabled || !_poolsReady) return;
    try { _faaahPool?.start(volume: 0.6); } catch (e) {
      print('[Audio] faaah error: $e');
    }
  }

  void playExplosionSound() {
    if (!viewModel.soundEnabled || !_poolsReady) return;
    try { _explosionPool?.start(volume: 0.7); } catch (e) {
      print('[Audio] explosion error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  REALISTIC BURST — heat flash + volumetric smoke + sparks + embers + debris
  // ─────────────────────────────────────────────────────────────
  void _createRealisticBurst(Vector2 position, Color color, {bool isLarge = false}) {
    final rng = math.Random();
    final scale = isLarge ? 1.8 : 1.0;

    // ── 0. Instantaneous heat flash ──────────────────────────────
    add(_HeatFlash(
      position: position.clone(),
      radius: (isLarge ? 55.0 : 32.0),
      flashColor: color,
    ));

    // ── 1. Volumetric smoke clouds (layered puffs) ───────────────
    final smokeCount = isLarge ? 22 : 14;
    for (int i = 0; i < smokeCount; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = (25 + rng.nextDouble() * 85) * scale;
      // Mix between hot-core color and dark aged smoke
      final isHot = i < smokeCount * 0.4;
      add(_RealisticSmokeParticle(
        position: position.clone() + Vector2(
          (rng.nextDouble() - 0.5) * 5,
          (rng.nextDouble() - 0.5) * 5,
        ),
        velocity: Vector2(math.cos(angle), math.sin(angle)) * speed,
        coreColor: isHot ? Colors.white : color,
        smokeColor: Color.lerp(const Color(0xFF1A1410), const Color(0xFF3A2C1E),
            rng.nextDouble())!,
        initialRadius: (4 + rng.nextDouble() * 9) * scale,
        lifeTime: 0.6 + rng.nextDouble() * 0.7,
        turbulenceFreq: 2.5 + rng.nextDouble() * 3.5,
        turbulenceAmp: (5 + rng.nextDouble() * 15) * scale,
        startDelay: rng.nextDouble() * 0.07,
        rotationSpeed: (rng.nextDouble() - 0.5) * 3.0,
      ));
    }

    // ── 2. Hot sparks — fast bright streaks ─────────────────────
    final sparkCount = isLarge ? 18 : 12;
    for (int i = 0; i < sparkCount; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = (100 + rng.nextDouble() * 220) * scale;
      final hue = 15 + rng.nextDouble() * 35; // orange to yellow
      final sparkColor = HSVColor.fromAHSV(1.0, hue, 0.95, 1.0).toColor();
      add(_HotSpark(
        position: position.clone(),
        velocity: Vector2(math.cos(angle), math.sin(angle)) * speed,
        sparkColor: sparkColor,
        lifeTime: 0.3 + rng.nextDouble() * 0.35,
      ));
    }

    // ── 3. Glowing embers — rise and flicker ─────────────────────
    final emberCount = isLarge ? 14 : 8;
    for (int i = 0; i < emberCount; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = (20 + rng.nextDouble() * 60) * scale;
      final hue = 10 + rng.nextDouble() * 40;
      add(_EmberParticle(
        position: position.clone() + Vector2(
          (rng.nextDouble() - 0.5) * 8 * scale,
          (rng.nextDouble() - 0.5) * 8 * scale,
        ),
        velocity: Vector2(math.cos(angle), math.sin(angle)) * speed,
        emberColor: HSVColor.fromAHSV(1.0, hue, 0.95, 1.0).toColor(),
        radius: (1.2 + rng.nextDouble() * 2.0) * (isLarge ? 1.4 : 1.0),
        lifeTime: 0.9 + rng.nextDouble() * 0.8,
      ));
    }

    // ── 4. Debris chunks — spinning fragments ────────────────────
    final debrisCount = isLarge ? 8 : 5;
    for (int i = 0; i < debrisCount; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = (60 + rng.nextDouble() * 140) * scale;
      // Charred / darkened version of bubble color
      final charred = Color.lerp(color, const Color(0xFF1A0A00), 0.5 + rng.nextDouble() * 0.3)!;
      add(_DebrisChunk(
        position: position.clone(),
        velocity: Vector2(math.cos(angle), math.sin(angle)) * speed,
        chunkColor: charred,
        size: (3.0 + rng.nextDouble() * 5.0) * scale,
        lifeTime: 0.5 + rng.nextDouble() * 0.4,
      ));
    }
  }

  @override
  Color backgroundColor() => const Color(0xFF0A0A1A);

  bool _initialized = false;
  bool _componentsLoaded = false;

  @override
  Future<void> onLoad() async {
    print('[Game] onLoad() started. Engine size: $size');
    try {
      viewModel.addListener(_onViewModelUpdate);

      // 1. Core visual layers
      print('[Game] Initializing background and starfield...');
      _background = _BackgroundComponent();
      _starfield = _StarfieldComponent();
      
      await add(_background);
      await add(_starfield);

      // 2. Interactive layers
      print('[Game] Initializing interactive components...');
      aimLine = AimLine();
      shooter = Shooter()..anchor = Anchor.center;
      
      await add(ScreenHitbox());
      await add(aimLine);
      await add(shooter!);

      _componentsLoaded = true;
      print('[Game] Basic components loaded. size=$size');

      // 3. Level setup
      if (size.x > 0 && size.y > 0) {
        _initWithSize(size);
      } else {
        print('[Game] Size is 0 during onLoad. Waiting for resize...');
      }

      // 4. Async audio
      unawaited(_loadAudioSafely());

      await super.onLoad();
      print('[Game] onLoad() completed successfully.');
    } catch (e, stack) {
      print('[Game] CRITICAL ERROR during onLoad: $e');
      print(stack);
      // Try to at least show a background if everything else fails
      add(RectangleComponent(size: size, paint: Paint()..color = Colors.red.withOpacity(0.1)));
    }
  }

  @override
  void onRemove() {
    viewModel.removeListener(_onViewModelUpdate);
    FlameAudio.bgm.dispose();
    _shootPool?.dispose();
    _popPool?.dispose();
    _explosionPool?.dispose();
    _faaahPool?.dispose();
    super.onRemove();
  }

  void _onViewModelUpdate() {
    _updateBgmState();
    if (viewModel.level == 1 && viewModel.score == 0 && _hasLevelStarted && !_isLevelChanging) {
      _startLevel();
    }
  }

  void _initWithSize(Vector2 s) {
    if (s.x <= 0 || s.y <= 0) return;
    print('[Game] _initWithSize: ${s.x}x${s.y}');
    
    _background.gameSize = s;
    _starfield.init(s);
    if (shooter != null) {
      shooter!.position = Vector2(s.x / 2, s.y - 100);
    }
    
    if (_initialized) return;
    _initialized = true;
    _startLevel();
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    if (newSize.x <= 0 || newSize.y <= 0) return;

    if (_componentsLoaded) {
      _initWithSize(newSize);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_isLevelChanging && !_isGameOver && _hasLevelStarted) {
      _autoShiftTimer += dt;
      if (_autoShiftTimer >= autoShiftInterval) {
        _autoShiftTimer = 0;
        _shiftGridDown();
      }
    }
  }

  void _startLevel() {
    _isLevelChanging = false;
    _isGameOver = false;
    _hasLevelStarted = false;
    _autoShiftTimer = 0;

    for (int r = 0; r < grid.length; r++) {
      for (int c = 0; c < grid[r].length; c++) {
        grid[r][c]?.removeFromParent();
        grid[r][c] = null;
      }
    }

    int rows = viewModel.getRowsCount();
    int colorCount = viewModel.getColorCount();

    final random = math.Random();
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < grid[row].length; col++) {
        final color = viewModel.bubbleColors[random.nextInt(colorCount)];
        bool isBomb = random.nextDouble() < 0.05;
        String? emoji;
        if (!isBomb && random.nextDouble() < 0.1) {
          emoji = animalEmojis[random.nextInt(animalEmojis.length)];
        }
        _addBubbleToGrid(row, col, color, isBomb: isBomb, emoji: emoji);
      }
    }
    _hasLevelStarted = true;
    _showLevelBanner();
  }

  void _showLevelBanner() {
    final banner = TextComponent(
      text: 'LEVEL ${viewModel.level}',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFE040FB),
          fontSize: 36,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
          shadows: [
            Shadow(color: Color(0xFFAA00FF), offset: Offset(0, 0), blurRadius: 20),
            Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 5),
          ],
        ),
      ),
      position: size / 2,
      anchor: Anchor.center,
    );
    add(banner);

    banner.add(ScaleEffect.to(
        Vector2.all(1.15), EffectController(duration: 0.3, reverseDuration: 0.3)));
    banner.add(MoveByEffect(
      Vector2(0, -120),
      EffectController(duration: 0.8, startDelay: 0.3, curve: Curves.easeIn),
      onComplete: () => banner.removeFromParent(),
    ));
  }

  void _addBubbleToGrid(int row, int col, Color color,
      {bool isBomb = false, bool isSuperPower = false, String? emoji}) {
    final pos = getPositionForGrid(row, col);
    final bubble = Bubble(
        color: color,
        position: pos,
        gridRow: row,
        gridCol: col,
        isBomb: isBomb,
        isSuperPower: isSuperPower,
        emoji: emoji);
    grid[row][col] = bubble;
    add(bubble);

    bubble.scale = Vector2.all(0);
    bubble.add(ScaleEffect.to(
        Vector2.all(1), EffectController(duration: 0.2, curve: Curves.easeOutBack)));
  }

  Vector2 getPositionForGrid(int row, int col) {
    double offsetX = (row % 2 != 0) ? bubbleRadius : 0;
    double gridWidth = grid[0].length * bubbleDiameter;
    double startX = (size.x - gridWidth) / 2 + bubbleRadius;
    return Vector2(
      startX + col * bubbleDiameter + offsetX,
      bubbleRadius + row * rowHeight + gridTopPadding,
    );
  }

  math.Point<int> getGridPosition(Vector2 position) {
    double gridWidth = grid[0].length * bubbleDiameter;
    double startX = (size.x - gridWidth) / 2 + bubbleRadius;

    int row = ((position.y - gridTopPadding - bubbleRadius - (bubbleRadius * 0.65)) /
            rowHeight)
        .round();
    row = row.clamp(0, grid.length - 1);

    double offsetX = (row % 2 != 0) ? bubbleRadius : 0;
    int col = ((position.x - startX - offsetX) / bubbleDiameter).round();
    col = col.clamp(0, grid[row].length - 1);

    return math.Point(row, col);
  }

  // ── MAIN SNAP LOGIC ─────────────────────────────────────────────
  void snapProjectile(Projectile projectile, {PositionComponent? hitComponent}) {
    if (projectile.isSnapped || _isLevelChanging) return;
    projectile.isSnapped = true;

    int row;
    int col;

    if (hitComponent is Bubble) {
      // BFS outward from hit bubble to find nearest empty cell
      final found = _findNearestEmpty(
          hitComponent.gridRow, hitComponent.gridCol, projectile.position,
          maxDepth: 3);
      if (found != null) {
        row = found.x;
        col = found.y;
      } else {
        // Absolute fallback: place at projectile's grid position
        final gp = getGridPosition(projectile.position);
        row = gp.x.clamp(0, grid.length - 1);
        col = gp.y.clamp(0, grid[0].length - 1);
      }
    } else {
      // Ceiling/wall hit — use projectile position
      final gridPos = getGridPosition(projectile.position);
      row = gridPos.x.clamp(0, grid.length - 1);
      col = gridPos.y.clamp(0, grid[0].length - 1);
    }

    // If computed cell is occupied, BFS outward
    if (grid[row][col] != null) {
      final found = _findNearestEmpty(row, col, projectile.position, maxDepth: 4);
      if (found != null) {
        row = found.x;
        col = found.y;
      } else {
        projectile.removeFromParent();
        return;
      }
    }

    // ── Lion super power projectile hits grid ────────────────────
    if (projectile.color == superPowerColor) {
      projectile.removeFromParent();
      final blastRow = row.clamp(0, grid.length - 1);
      final blastCol = col.clamp(0, grid[0].length - 1);
      _lionBlast(blastRow, blastCol);
      _removeFloatingBubbles();
      _checkLevelProgress();
      return;
    }

    // ── Bomb check ──────────────────────────────────────────────────
    bool hitBomb = grid[row][col]?.isBomb ?? false;
    if (!hitBomb) {
      for (final n in _getNeighbors(row, col)) {
        if (grid[n.x][n.y]?.isBomb ?? false) {
          row = n.x;
          col = n.y;
          hitBomb = true;
          break;
        }
      }
    }

    if (hitBomb) {
      projectile.removeFromParent();
      _explodeBomb(row, col);
      _removeFloatingBubbles();
      _checkLevelProgress();
      return;
    }

    // Final occupancy guard
    if (grid[row][col] != null) {
      projectile.removeFromParent();
      return;
    }

    final color = projectile.color;
    final finalPos = getPositionForGrid(row, col);

    final newBubble =
        Bubble(color: color, position: finalPos, gridRow: row, gridCol: col);
    grid[row][col] = newBubble;
    newBubble.scale = Vector2.all(0);
    add(newBubble);

    projectile.add(MoveEffect.to(
      finalPos,
      EffectController(duration: 0.035),
      onComplete: () {
        projectile.removeFromParent();
        newBubble.add(ScaleEffect.to(
            Vector2.all(1),
            EffectController(duration: 0.14, curve: Curves.easeOutBack)));
        final matched = _checkMatches(row, col, color);
        if (!matched) {
          playFaaahSound();
        }
        _removeFloatingBubbles();
        _checkLevelProgress();
      },
    ));
  }

  /// BFS from (startRow, startCol) outward up to [maxDepth] rings.
  /// Returns the empty cell closest to [refPos], or null if none found.
  math.Point<int>? _findNearestEmpty(
      int startRow, int startCol, Vector2 refPos,
      {int maxDepth = 3}) {
    final visited = <math.Point<int>>{};
    final queue = <math.Point<int>>[math.Point(startRow, startCol)];
    visited.add(math.Point(startRow, startCol));

    math.Point<int>? best;
    double bestDist = double.infinity;
    int depth = 0;

    while (queue.isNotEmpty && depth <= maxDepth) {
      final nextQueue = <math.Point<int>>[];
      for (final p in queue) {
        if (grid[p.x][p.y] == null) {
          final pos = getPositionForGrid(p.x, p.y);
          final d = refPos.distanceTo(pos);
          if (d < bestDist) {
            bestDist = d;
            best = p;
          }
        }
        for (final n in _getNeighbors(p.x, p.y)) {
          if (!visited.contains(n)) {
            visited.add(n);
            nextQueue.add(n);
          }
        }
      }
      if (best != null) return best; // Found at this depth — stop
      queue
        ..clear()
        ..addAll(nextQueue);
      depth++;
    }
    return best;
  }

  void _shiftGridDown() {
    if (_isLevelChanging || _isGameOver) return;

    // If any bubble has already reached 75% of screen height, stop shifting.
    // The grid stays frozen where it is — player keeps playing.
    for (int r = grid.length - 1; r >= 0; r--) {
      for (int c = 0; c < grid[r].length; c++) {
        if (grid[r][c] != null) {
          final pos = getPositionForGrid(r, c);
          if (pos.y > size.y * 0.75) {
            return; // Freeze — no more shifting, no game over
          }
        }
      }
    }

    for (int r = grid.length - 1; r > 0; r--) {
      for (int c = 0; c < grid[r].length; c++) {
        grid[r][c] = grid[r - 1][c];
        if (grid[r][c] != null) {
          grid[r][c]!.gridRow = r;
          final newPos = getPositionForGrid(r, c);
          grid[r][c]!.add(
              MoveEffect.to(newPos, EffectController(duration: shiftAnimDuration, curve: Curves.easeOut)));
        }
      }
    }

    final random = math.Random();
    int colorCount = viewModel.getColorCount();
    for (int col = 0; col < grid[0].length; col++) {
      final color = viewModel.bubbleColors[random.nextInt(colorCount)];
      bool isBomb = random.nextDouble() < 0.05;
      String? emoji;
      if (!isBomb && random.nextDouble() < 0.1) {
        emoji = animalEmojis[random.nextInt(animalEmojis.length)];
      }
      _addBubbleToGrid(0, col, color, isBomb: isBomb, emoji: emoji);
    }
  }

  void _triggerGameOver() {
    if (_isGameOver) return;
    _isGameOver = true;
    onGameOver?.call();
    // Optional: play a sad sound or show a burst
  }

  void _explodeBomb(int row, int col) {
    final List<math.Point<int>> toRemove = [];
    for (int r = 0; r < grid.length; r++) {
      if (grid[r][col] != null) toRemove.add(math.Point(r, col));
    }
    for (int c = 0; c < grid[row].length; c++) {
      if (grid[row][c] != null) toRemove.add(math.Point(row, c));
    }

    final bombPos = getPositionForGrid(row, col);
    playExplosionSound();

    for (final p in toRemove) {
      final b = grid[p.x][p.y];
      if (b != null) {
        viewModel.addScore(20, b.color);
        _popBubble(b);
        grid[p.x][p.y] = null;
      }
    }

    // ── Large realistic explosion burst ─────────────────────────
    _createRealisticBurst(bombPos, const Color(0xFFFF6600), isLarge: true);

    // Extra secondary burst ring
    final rng = math.Random();
    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * math.pi * 2;
      final offset = Vector2(math.cos(angle), math.sin(angle)) * 20;
      Future.delayed(Duration(milliseconds: 60 + (i * 25)), () {
        if (!_isLevelChanging) {
          _createRealisticBurst(bombPos + offset, const Color(0xFFFF4400), isLarge: false);
        }
      });
    }

    // Shockwave ring — expands then vanishes
    final shockwave = CircleComponent(
      radius: bubbleRadius * 0.5,
      position: bombPos,
      anchor: Anchor.center,
      paint: Paint()
        ..color = const Color(0xAAFF8800)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    add(shockwave);
    shockwave.add(ScaleEffect.to(
      Vector2.all(18),
      EffectController(duration: 0.55, curve: Curves.easeOut),
      onComplete: () => shockwave.removeFromParent(),
    ));

    // Second outer shockwave, delayed
    final shockwave2 = CircleComponent(
      radius: bubbleRadius * 0.4,
      position: bombPos,
      anchor: Anchor.center,
      paint: Paint()
        ..color = const Color(0x66FFAA00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    add(shockwave2);
    shockwave2.add(ScaleEffect.to(
      Vector2.all(25),
      EffectController(duration: 0.7, startDelay: 0.08, curve: Curves.easeOut),
      onComplete: () => shockwave2.removeFromParent(),
    ));
  }

  void _popBubble(Bubble b) {
    _createRealisticBurst(b.position, b.color);
    playPopSound();

    // Extra points for animal bubbles
    if (b.emoji != null) {
      viewModel.addScore(50, b.color); // +50 bonus
      add(_ScorePopup(
        'BONUS +50!',
        b.position + Vector2(0, -30),
        const Color(0xFFFFEB3B),
      ));
    }

    b.add(ScaleEffect.to(
      Vector2.all(1.5),
      EffectController(duration: popAnimDuration * 0.6),
      onComplete: () {
        b.add(ScaleEffect.to(
          Vector2.zero(),
          EffectController(duration: popAnimDuration, curve: Curves.easeIn),
          onComplete: () => b.removeFromParent(),
        ));
      },
    ));
  }

  bool _checkMatches(int row, int col, Color color) {
    final List<math.Point<int>> matches = [];
    final List<math.Point<int>> toVisit = [math.Point(row, col)];
    final Set<math.Point<int>> visited = {math.Point(row, col)};

    while (toVisit.isNotEmpty) {
      final current = toVisit.removeLast();
      final b = grid[current.x][current.y];
      if (b != null && b.color == color && !b.isBomb) {
        matches.add(current);
        for (final neighbor in _getNeighbors(current.x, current.y)) {
          if (!visited.contains(neighbor)) {
            visited.add(neighbor);
            toVisit.add(neighbor);
          }
        }
      }
    }

    if (matches.length >= 3) {
      // Show combo score popup
      if (matches.length >= 5) {
        add(_ScorePopup(
          'COMBO x${matches.length}!',
          getPositionForGrid(row, col) + Vector2(0, -20),
          const Color(0xFFFFD700),
        ));
      }
      for (final m in matches) {
        final b = grid[m.x][m.y];
        if (b != null) {
          viewModel.addScore(10, b.color);
          _popBubble(b);
        }
        grid[m.x][m.y] = null;
      }
      return true;
    }
    return false;
  }

  void _checkLevelProgress() {
    if (!_hasLevelStarted || _isLevelChanging || _isGameOver) return;

    // Check if the grid is entirely empty
    bool isGridEmpty = true;
    for (int r = 0; r < grid.length; r++) {
      for (int c = 0; c < grid[r].length; c++) {
        if (grid[r][c] != null) {
          isGridEmpty = false;
          break;
        }
      }
      if (!isGridEmpty) break;
    }

    if ((viewModel.isLevelComplete() || isGridEmpty)) {
      _isLevelChanging = true;

      // 1. Bonus points for clearing the level
      final bonus = viewModel.levelCompletionBonus;
      viewModel.addBonus(bonus);

      // 2. Award a super power for next level
      viewModel.awardSuperPower();

      // 3. Fire the level-complete callback → Flutter overlay
      onLevelComplete?.call(viewModel.level, bonus);
      playExplosionSound(); // A celebratory sound

      // 4. Show interstitial ad if available
      if (buildContext != null) {
        AdService.showInterstitialAdWithFallback(buildContext!);
      }

      // 5. Advance level after overlay duration
      Future.delayed(Duration(milliseconds: isGridEmpty ? 2800 : 3200), () {
        viewModel.nextLevel();
        _startLevel();
      });
    }
  }

  List<math.Point<int>> _getNeighbors(int row, int col) {
    List<math.Point<int>> neighbors = [];
    final List<List<int>> offsets = (row % 2 == 0)
        ? [[-1, 0], [-1, -1], [0, -1], [0, 1], [1, 0], [1, -1]]
        : [[-1, 0], [-1, 1], [0, -1], [0, 1], [1, 0], [1, 1]];
    for (final offset in offsets) {
      int r = row + offset[0];
      int c = col + offset[1];
      if (r >= 0 && r < grid.length && c >= 0 && c < grid[r].length) {
        neighbors.add(math.Point(r, c));
      }
    }
    return neighbors;
  }

  void _removeFloatingBubbles() {
    final Set<math.Point<int>> connected = {};
    final List<math.Point<int>> toVisit = [];
    for (int col = 0; col < grid[0].length; col++) {
      if (grid[0][col] != null) {
        final p = math.Point(0, col);
        toVisit.add(p);
        connected.add(p);
      }
    }
    while (toVisit.isNotEmpty) {
      final current = toVisit.removeLast();
      for (final neighbor in _getNeighbors(current.x, current.y)) {
        if (!connected.contains(neighbor) && grid[neighbor.x][neighbor.y] != null) {
          connected.add(neighbor);
          toVisit.add(neighbor);
        }
      }
    }
    for (int r = 0; r < grid.length; r++) {
      for (int c = 0; c < grid[r].length; c++) {
        final b = grid[r][c];
        if (b != null && !connected.contains(math.Point(r, c))) {
          viewModel.addScore(15, b.color);

          // Bonus for floating emoji bubbles
          if (b.emoji != null) {
            viewModel.addScore(50, b.color);
            add(_ScorePopup(
              'SAVED! +50',
              b.position + Vector2(0, -30),
              const Color(0xFF00E5FF),
            ));
          }

          b.add(MoveByEffect(
              Vector2(0, 520), EffectController(duration: 0.45, curve: Curves.easeIn),
              onComplete: () => b.removeFromParent()));
          b.add(ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.45)));
          grid[r][c] = null;
        }
      }
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    if (!_componentsLoaded || !_initialized || _isLevelChanging) return;
    _lastInputPos = event.localPosition;
    _isAiming = _isValidAimZone(_lastInputPos);
    if (_isAiming) {
      _updateDirection(_lastInputPos);
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!_componentsLoaded || !_initialized || _isLevelChanging || !_isAiming) return;
    // canvasEndPosition = absolute finger position in game-canvas coordinates.
    // This matches the coordinate space of DragStartEvent.localPosition and
    // all TapEvent.localPosition values, so there is zero drift.
    _lastInputPos = event.canvasEndPosition;
    _updateDirection(_lastInputPos);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (!_componentsLoaded || !_initialized || !_isAiming) {
      _isAiming = false;
      return;
    }
    
    if (!_isLevelChanging) {
      shooter?.shoot();
    }
    _isAiming = false;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    _isAiming = false;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!_componentsLoaded || !_initialized || _isLevelChanging) return;
    _isAiming = _isValidAimZone(event.localPosition);
    if (_isAiming) {
      _updateDirection(event.localPosition);
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (!_componentsLoaded || !_initialized || _isLevelChanging || !_isAiming) {
      _isAiming = false;
      return;
    }
    _updateDirection(event.localPosition);
    shooter?.shoot();
    _isAiming = false;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    // Keep _isAiming as it might have transitioned to a pan
  }

  bool _isValidAimZone(Vector2 pos) {
    final s = shooter;
    if (s == null) return false;
    // Ignore touches below the shooter (e.g., navigation bar area)
    // s.position.y is size.y - 100, so this allows everything above size.y - 110
    return pos.y < s.position.y - 10;
  }

  void _updateDirection(Vector2 targetPos) {
    final s = shooter;
    if (s == null || !_initialized) return;

    // Calculate direction from shooter center to touch point
    final dir = targetPos - s.position;

    // Guard: ignore touches that are at or below the shooter (would fire down)
    if (dir.y >= 0) return;

    // Calculate angle relative to the "up" vector (0, -1)
    // atan2(dx, -dy) → 0 = straight up, positive = right, negative = left
    final angle = math.atan2(dir.x, -dir.y);

    // Clamp to prevent too-shallow (near-horizontal) or downward shots.
    // ~82 degrees from vertical on each side.
    const double maxAngle = 1.43;
    // Minimum angle from vertical (prevents pure 90° horizontal shots)
    // 1.35 rad ≈ 77°; feel free to tighten if you want a narrower cone.
    s.targetAngle = angle.clamp(-maxAngle, maxAngle);

    // Update aimLine direction to match the clamped shooter target angle
    aimLine.direction = Vector2(math.sin(s.targetAngle), -math.cos(s.targetAngle));
  }
}
