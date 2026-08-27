import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _keyLevel = 'current_level';
  static const String _keyScore = 'current_score';
  static const String _keySuperPowerCount = 'super_power_count';
  static const String _keySoundEnabled = 'sound_enabled';

  static Future<void> saveGameState(int level, int score, int superPowerCount, bool soundEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLevel, level);
    await prefs.setInt(_keyScore, score);
    await prefs.setInt(_keySuperPowerCount, superPowerCount);
    await prefs.setBool(_keySoundEnabled, soundEnabled);
  }

  static Future<Map<String, dynamic>> loadGameState() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'level': prefs.getInt(_keyLevel) ?? 1,
      'score': prefs.getInt(_keyScore) ?? 0,
      'superPowerCount': prefs.getInt(_keySuperPowerCount) ?? 0,
      'soundEnabled': prefs.getBool(_keySoundEnabled) ?? true,
    };
  }

  static Future<void> clearGameState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLevel);
    await prefs.remove(_keyScore);
    await prefs.remove(_keySuperPowerCount);
  }
}
