import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../services/local_storage_service.dart';

class GameViewModel extends ChangeNotifier {
  GameViewModel() {
    print('[GameViewModel] initialized');
  }

  int _level = 1;
  int get level => _level;

  int _score = 0;
  int get score => _score;

  int _bubblesPoppedInLevel = 0;
  int get bubblesPoppedInLevel => _bubblesPoppedInLevel;

  final Map<Color, int> _colorCounts = {};
  Map<Color, int> get colorCounts => Map.unmodifiable(_colorCounts);

  // ─── Super Power system ──────────────────────────────────────────
  int _superPowerCount = 0;
  int get superPowerCount => _superPowerCount;

  bool _soundEnabled = true;
  bool get soundEnabled => _soundEnabled;

  static const int maxSuperPowers = 3;

  // ─── Level Greeting state ──────────────────────────────────────────
  bool _showGreeting = false;
  bool get showGreeting => _showGreeting;

  int _completedLevel = 1;
  int get completedLevel => _completedLevel;

  int _earnedBonus = 0;
  int get earnedBonus => _earnedBonus;

  void showLevelComplete(int level, int bonus) {
    _completedLevel = level;
    _earnedBonus = bonus;
    _showGreeting = true;
    _scheduleNotify();
  }

  void dismissGreeting() {
    _showGreeting = false;
    _scheduleNotify();
  }

  Future<void> init() async {
    print('[GameViewModel] init() started');
    try {
      final state = await LocalStorageService.loadGameState().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          print('[GameViewModel] LocalStorage timeout, using defaults');
          return {'level': 1, 'score': 0, 'superPowerCount': 0, 'soundEnabled': true};
        },
      );
      _level = state['level'] ?? 1;
      _score = state['score'] ?? 0;
      _superPowerCount = state['superPowerCount'] ?? 0;
      _soundEnabled = state['soundEnabled'] ?? true;
      print('[GameViewModel] state loaded: level=$_level, score=$_score');
    } catch (e) {
      print('[GameViewModel] Error loading state: $e');
    }
    notifyListeners();
  }

  Future<void> _saveState() async {
    await LocalStorageService.saveGameState(_level, _score, _superPowerCount, _soundEnabled);
  }

  void toggleSound() {
    _soundEnabled = !_soundEnabled;
    _saveState();
    notifyListeners();
  }

  /// Award one super power after clearing a level. Capped at [maxSuperPowers].
  void awardSuperPower() {
    if (_superPowerCount < maxSuperPowers) {
      _superPowerCount++;
      _saveState();
      _scheduleNotify();
    }
  }

  /// Returns true and deducts one if available; false otherwise.
  bool useSuperPower() {
    if (_superPowerCount <= 0) return false;
    _superPowerCount--;
    _saveState();
    _scheduleNotify();
    return true;
  }

  /// How many full rows + full columns the Lion blast removes (= current level).
  int get superPowerBlastSize => _level;

  /// Bonus points awarded on level completion (displayed as popup).
  int get levelCompletionBonus => 100 * _level;

  /// Add a raw score bonus without affecting color counts or bubble-popped counter.
  void addBonus(int points) {
    _score += points;
    _scheduleNotify();
  }

  // ────────────────────────────────────────────────────────────────

  final List<Color> bubbleColors = [
    const Color(0xFFFF1744), // Neon Pink/Red
    const Color(0xFF00E676), // Spring Green
    const Color(0xFF2979FF), // Electric Blue
    const Color(0xFFFFEA00), // Bright Yellow
    const Color(0xFFD500F9), // Vivid Purple
    const Color(0xFF00E5FF), // Cyan/Teal
  ];

  // Difficulty scaling: more pops required per level
  int get levelTarget => 200 + (_level * 75); 

  // Starting rows: begin at 4, grow with level, hard-capped at 7 rows
  // so the grid never exceeds ~50 % of screen height on typical phones.
  int getRowsCount() => 4 + (_level ~/ 2).clamp(0, 3);

  // Colors: introduce more colors sooner
  int getColorCount() => math.min(bubbleColors.length, 4 + (_level ~/ 2));

  // ─── Throttled notify: at most ONE rebuild per frame ───────────────
  bool _pendingNotify = false;

  void _scheduleNotify() {
    if (_pendingNotify) return;
    _pendingNotify = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pendingNotify = false;
      notifyListeners();
    });
  }

  void addScore(int points, Color color) {
    _score += points;
    _bubblesPoppedInLevel++;
    _colorCounts[color] = (_colorCounts[color] ?? 0) + 1;
    // Do NOT save state on every bubble pop — that causes disk I/O lag.
    // State is persisted at level completion, reset, and sound toggle.
    _scheduleNotify();
  }

  bool isLevelComplete() => _bubblesPoppedInLevel >= levelTarget;

  void nextLevel() {
    _level++;
    _bubblesPoppedInLevel = 0;
    _colorCounts.clear();
    _saveState();
    notifyListeners();
  }

  void resetGame() {
    _level = 1;
    _score = 0;
    _bubblesPoppedInLevel = 0;
    _superPowerCount = 0;
    _colorCounts.clear();
    LocalStorageService.clearGameState();
    notifyListeners();
  }
}
