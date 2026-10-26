import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _keyLevel = 'current_level';
  static const String _keyScore = 'current_score';
  static const String _keySuperPowerCount = 'super_power_count';
  static const String _keySoundEnabled = 'sound_enabled';
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyRecordedClips = 'recorded_clips';

  static Future<void> saveGameState(int level, int score, int superPowerCount, bool soundEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLevel, level);
    await prefs.setInt(_keyScore, score);
    await prefs.setInt(_keySuperPowerCount, superPowerCount);
    await prefs.setBool(_keySoundEnabled, soundEnabled);
  }

  static Future<void> setLoggedIn(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, isLoggedIn);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
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

  // ── Recorded Clips Local Storage Operations ──

  static Future<List<Map<String, dynamic>>> getRecordedClips() async {
    final prefs = await SharedPreferences.getInstance();
    final String? clipsJsonStr = prefs.getString(_keyRecordedClips);
    if (clipsJsonStr == null || clipsJsonStr.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> decoded = jsonDecode(clipsJsonStr);
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveRecordedClip(Map<String, dynamic> clip) async {
    final clips = await getRecordedClips();
    clips.insert(0, clip); // Insert newest at top
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRecordedClips, jsonEncode(clips));
  }

  static Future<void> deleteRecordedClip(String id) async {
    final clips = await getRecordedClips();
    clips.removeWhere((item) => item['id'] == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRecordedClips, jsonEncode(clips));
  }

  static Future<void> clearAllRecordedClips() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRecordedClips);
  }
}
