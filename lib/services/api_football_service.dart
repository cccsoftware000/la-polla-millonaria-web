// lib/services/api_football_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiFootballService {
  static const String _BASE_FUNCTION_URL =
      'https://us-central1-la-polla-millonaria.cloudfunctions.net';

  static const String _CACHE_KEY = 'cached_live_fixtures';
  static const Duration _CACHE_DURATION = Duration(minutes: 5);

  /// Obtener resultados en vivo (con caché)
  static Future<List<Map<String, dynamic>>> getLiveFixtures() async {
    // Verificar caché
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_CACHE_KEY);
    final cacheTime = prefs.getInt('${_CACHE_KEY}_time');

    if (cached != null && cacheTime != null) {
      final age = DateTime.now().millisecondsSinceEpoch - cacheTime;
      if (age < _CACHE_DURATION.inMilliseconds) {
        print('📦 Usando datos en caché de live fixtures');
        try {
          final decoded = jsonDecode(cached);
          if (decoded is List) {
            return decoded.cast<Map<String, dynamic>>();
          }
        } catch (e) {
          print('Error decodificando caché: $e');
        }
      }
    }

    try {
      final response = await http.get(
        Uri.parse('$_BASE_FUNCTION_URL/getLiveFixtures'),
        headers: {'Content-Type': 'application/json'},
      );

      print('📡 Respuesta de Cloud Function: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ✅ Manejar diferentes formatos de respuesta
        List<Map<String, dynamic>> fixtures = [];

        if (data['response'] != null && data['response'] is List) {
          fixtures = List<Map<String, dynamic>>.from(data['response']);
        } else if (data is List) {
          fixtures = List<Map<String, dynamic>>.from(data);
        } else if (data['data'] != null && data['data'] is List) {
          fixtures = List<Map<String, dynamic>>.from(data['data']);
        }

        if (fixtures.isNotEmpty) {
          // Guardar en caché
          await prefs.setString(_CACHE_KEY, jsonEncode(fixtures));
          await prefs.setInt('${_CACHE_KEY}_time', DateTime.now().millisecondsSinceEpoch);
        }

        return fixtures;
      } else if (response.statusCode == 429) {
        print('⚠️ Límite de API alcanzado');
        if (cached != null) {
          try {
            final decoded = jsonDecode(cached);
            if (decoded is List) {
              return decoded.cast<Map<String, dynamic>>();
            }
          } catch (e) {
            return [];
          }
        }
        return [];
      } else {
        print('Error en API: ${response.statusCode}');
        if (cached != null) {
          try {
            final decoded = jsonDecode(cached);
            if (decoded is List) {
              return decoded.cast<Map<String, dynamic>>();
            }
          } catch (e) {
            return [];
          }
        }
        return [];
      }
    } catch (e) {
      print('Error getting live fixtures: $e');
      if (cached != null) {
        try {
          final decoded = jsonDecode(cached);
          if (decoded is List) {
            return decoded.cast<Map<String, dynamic>>();
          }
        } catch (e) {
          return [];
        }
      }
      return [];
    }
  }

  /// Obtener resultado de un fixture por ID
  static Future<Map<String, dynamic>?> getFixture(int fixtureId) async {
    try {
      final response = await http.get(
        Uri.parse('$_BASE_FUNCTION_URL/getFixtureById?fixtureId=$fixtureId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['response'] != null && data['response'] is List && data['response'].isNotEmpty) {
          return Map<String, dynamic>.from(data['response'][0]);
        } else if (data is Map<String, dynamic>) {
          return data;
        }
      }
      return null;
    } catch (e) {
      print('Error getting fixture $fixtureId: $e');
      return null;
    }
  }

  /// Obtener partidos por fecha
  /// Obtener resultados de partidos de una fecha específica (incluye finalizados)
  static Future<List<Map<String, dynamic>>> getFixturesByDate(DateTime date) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final response = await http.get(
        Uri.parse('$_BASE_FUNCTION_URL/getFixturesByDate?date=$dateStr'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['response'] != null && data['response'] is List) {
          return List<Map<String, dynamic>>.from(data['response']);
        }
      }
      return [];
    } catch (e) {
      print('Error getting fixtures by date: $e');
      return [];
    }
  }

  /// Limpiar caché
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_CACHE_KEY);
    await prefs.remove('${_CACHE_KEY}_time');
    print('🧹 Caché de live fixtures limpiada');
  }
}