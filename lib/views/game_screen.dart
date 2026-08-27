import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/game_viewmodel.dart';
import '../game/bubble_shooter_game.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late BubbleShooterGame _game;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    print('[GameScreen] initState() started');
    
    final viewModel = Provider.of<GameViewModel>(context, listen: false);
    _game = BubbleShooterGame(viewModel);

    _game.onLevelComplete = (level, bonus) => viewModel.showLevelComplete(level, bonus);
    _game.onGameOver = () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GAME OVER!'), backgroundColor: Colors.redAccent),
        );
        viewModel.resetGame();
      }
    };

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    print('[GameScreen] initState() finished');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Consumer<GameViewModel>(
        builder: (context, viewModel, child) {
          return Stack(
            children: [
              // 1. THE GAME
              Positioned.fill(
                child: GameWidget(
                  game: _game,
                  loadingBuilder: (context) => const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE040FB)),
                  ),
                ),
              ),

              // 2. TOP HUD
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _TopHud(
                  viewModel: viewModel,
                  pulseAnim: _pulseAnim,
                  onReset: () => _game.viewModel.resetGame(),
                ),
              ),

              // 3. SUPER POWER BUTTON
              if (viewModel.superPowerCount > 0)
                Positioned(
                  bottom: 130,
                  right: 16,
                  child: _SuperPowerButton(
                    count: viewModel.superPowerCount,
                    blastSize: viewModel.superPowerBlastSize,
                    onTap: () => _game.activateStoredSuperPower(),
                    pulseAnim: _pulseAnim,
                  ),
                ),

              // 4. LEVEL GREETING
              if (viewModel.showGreeting)
                _SimpleGreeting(
                  level: viewModel.completedLevel,
                  bonus: viewModel.earnedBonus,
                  onContinue: () => viewModel.dismissGreeting(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TopHud extends StatelessWidget {
  final GameViewModel viewModel;
  final Animation<double> pulseAnim;
  final VoidCallback onReset;

  const _TopHud({
    required this.viewModel,
    required this.pulseAnim,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (viewModel.bubblesPoppedInLevel / viewModel.levelTarget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _GlassChip(label: 'LVL', value: '${viewModel.level}'),
              const Expanded(
                child: Center(
                  child: Text(
                    'BUBBLE BLAST',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2),
                  ),
                ),
              ),
              _GlassChip(label: 'SCORE', value: '${viewModel.score}'),
              const SizedBox(width: 8),
              _CircleButton(
                icon: viewModel.soundEnabled ? Icons.music_note : Icons.music_off,
                onTap: () => viewModel.toggleSound(),
                color: viewModel.soundEnabled ? const Color(0xFFE040FB) : Colors.white24,
              ),
              const SizedBox(width: 8),
              _CircleButton(
                icon: Icons.refresh,
                onTap: onReset,
                color: Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress Bar
          Row(
            children: [
              Text('${viewModel.bubblesPoppedInLevel}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(height: 6, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(3))),
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 300),
                      widthFactor: progress,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: const LinearGradient(colors: [Color(0xFFE040FB), Color(0xFF40C4FF)]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('${viewModel.levelTarget}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          // Color Counts
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: viewModel.bubbleColors.map((color) {
                final count = viewModel.colorCounts[color] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text('$count', style: const TextStyle(color: Colors.white60, fontSize: 10)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final String label;
  final String value;
  const _GlassChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Text('$label: $value', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _CircleButton({required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _SuperPowerButton extends StatelessWidget {
  final int count;
  final int blastSize;
  final VoidCallback onTap;
  final Animation<double> pulseAnim;

  const _SuperPowerButton({
    required this.count,
    required this.blastSize,
    required this.onTap,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulseAnim,
        builder: (context, child) {
          return Transform.scale(
            scale: pulseAnim.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🦁 ×$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('$blastSize ROWS', style: const TextStyle(color: Colors.white70, fontSize: 9)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SimpleGreeting extends StatelessWidget {
  final int level;
  final int bonus;
  final VoidCallback onContinue;
  const _SimpleGreeting({required this.level, required this.bonus, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A3A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE040FB)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉 LEVEL CLEAR!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Level $level completed', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              Text('+$bonus BONUS', style: const TextStyle(color: Colors.yellow, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE040FB)),
                child: const Text('CONTINUE', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
