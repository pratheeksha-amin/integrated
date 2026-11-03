import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TranslationCacheService {
  static const String _prefix = "cached_trans_";

  static Future<void> save(String medicineName, String langCode, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final key = "$_prefix${langCode}_$medicineName".toLowerCase().replaceAll(' ', '_');
    await prefs.setString(key, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> get(String medicineName, String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    final key = "$_prefix${langCode}_$medicineName".toLowerCase().replaceAll(' ', '_');
    final cached = prefs.getString(key);
    if (cached != null) {
      try {
        return jsonDecode(cached) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}
