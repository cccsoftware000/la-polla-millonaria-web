// lib/services/cache_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/polla_model.dart';

class CacheService {
  static const String _cacheMatchesKey = 'cached_matches';
  static const String _cachePollaKey = 'cached_polla';
  static const String _cacheUserKey = 'cached_user';
  static const String _cacheTimestampKey = 'cache_timestamp';
  static const int _cacheDurationMinutes = 10;

  static Future<void> cacheMatches(List<Map<String, dynamic>> matches) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheMatchesKey, jsonEncode(matches));
    await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<List<Map<String, dynamic>>?> getCachedMatches() async {
    final prefs = await SharedPreferences.getInstance();

    final timestamp = prefs.getInt(_cacheTimestampKey);
    if (timestamp != null) {
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > _cacheDurationMinutes * 60 * 1000) {
        return null;
      }
    }

    final json = prefs.getString(_cacheMatchesKey);
    if (json != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(json));
    }
    return null;
  }

  // ✅ Corregido - toMap() existe en PollaModel
  static Future<void> cachePolla(PollaModel polla) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachePollaKey, jsonEncode(polla.toMap()));
  }

  static Future<PollaModel?> getCachedPolla() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_cachePollaKey);
    if (json != null) {
      final Map<String, dynamic> map = jsonDecode(json);
      return PollaModel.fromMap('cached', map);
    }
    return null;
  }

  // ✅ Agregado - cache de usuario
  static Future<void> cacheUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheUserKey, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_cacheUserKey);
    if (json != null) {
      return jsonDecode(json);
    }
    return null;
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheMatchesKey);
    await prefs.remove(_cachePollaKey);
    await prefs.remove(_cacheUserKey);
    await prefs.remove(_cacheTimestampKey);
  }
}