// lib/services/match_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/date_utils.dart';
import '../models/match_model.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener partidos de una polla específica
  Future<List<MatchModel>> getMatchesByPolla(String pollaId) async {
    try {
      final snapshot = await _firestore
          .collection('matches')
          .where('pollaId', isEqualTo: pollaId)
          .get();

      var matches = snapshot.docs.map((doc) {
        final data = doc.data();
        // ✅ Ya está en hora Colombia, no convertir nada
        final dateTime = (data['dateTime'] as Timestamp).toDate();

        return MatchModel(
          id: doc.id,
          pollaId: data['pollaId'] ?? '',
          local: data['local'] ?? '',
          visitor: data['visitor'] ?? '',
          localLogo: data['localLogo'] ?? '',
          visitorLogo: data['visitorLogo'] ?? '',
          dateTime: dateTime,  // ✅ Hora Colombia
          status: data['status'] ?? 'UPCOMING',
        );
      }).toList();

      matches.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return matches;
    } catch (e) {
      print('Error getting matches: $e');
      return [];
    }
  }

  // Obtener partidos como Map para BetScreen
  Future<List<Map<String, dynamic>>> getMatchesForBetScreen(String pollaId) async {
    try {
      final snapshot = await _firestore
          .collection('matches')
          .where('pollaId', isEqualTo: pollaId)
          .get();

      var matches = snapshot.docs.map((doc) {
        final data = doc.data();
        // ✅ Ya está en hora Colombia
        final colombiaDateTime = (data['dateTime'] as Timestamp).toDate();

        return {
          'id': doc.id,
          'tournament': data['tournament'] ?? '⚽ Partido',
          'local': data['local'] ?? '',
          'visitor': data['visitor'] ?? '',
          'localLogo': data['localLogo'] ?? '⚽',
          'visitorLogo': data['visitorLogo'] ?? '⚽',
          'localEmoji': data['localEmoji'] ?? '⚽',
          'visitorEmoji': data['visitorEmoji'] ?? '⚽',
          'dateTime': colombiaDateTime,  // ✅ Hora Colombia
          'group': data['group'] ?? '',
          'status': data['status'] ?? 'UPCOMING',
          'dateStr': data['dateStr'] ?? '',
          'time': data['time'] ?? '',
          'realHomeScore': data['realHomeScore'],
          'realAwayScore': data['realAwayScore'],
        };
      }).toList();

      matches.sort((a, b) => (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime));
      return matches;
    } catch (e) {
      print('Error getting matches for bet screen: $e');
      return [];
    }
  }

  // Stream de partidos en tiempo real
  Stream<List<MatchModel>> streamMatchesByPolla(String pollaId) {
    return _firestore
        .collection('matches')
        .where('pollaId', isEqualTo: pollaId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final colombiaDateTime = (data['dateTime'] as Timestamp).toDate();

        return MatchModel(
          id: doc.id,
          pollaId: data['pollaId'] ?? '',
          local: data['local'] ?? '',
          visitor: data['visitor'] ?? '',
          localLogo: data['localLogo'] ?? '',
          visitorLogo: data['visitorLogo'] ?? '',
          dateTime: colombiaDateTime,  // ✅ Hora Colombia
          status: data['status'] ?? 'UPCOMING',
        );
      }).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    });
  }

  // Obtener el primer partido
  Future<MatchModel?> getFirstMatchByPolla(String pollaId) async {
    try {
      final snapshot = await _firestore
          .collection('matches')
          .where('pollaId', isEqualTo: pollaId)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final allMatches = snapshot.docs.map((doc) {
        final data = doc.data();
        final colombiaDateTime = (data['dateTime'] as Timestamp).toDate();

        return MatchModel(
          id: doc.id,
          pollaId: data['pollaId'] ?? '',
          local: data['local'] ?? '',
          visitor: data['visitor'] ?? '',
          localLogo: data['localLogo'] ?? '',
          visitorLogo: data['visitorLogo'] ?? '',
          dateTime: colombiaDateTime,  // ✅ Hora Colombia
          status: data['status'] ?? 'UPCOMING',
        );
      }).toList();

      allMatches.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return allMatches.isNotEmpty ? allMatches.first : null;
    } catch (e) {
      print('Error getting first match: $e');
      return null;
    }
  }

  Future<void> updateMatchResult({
    required String matchId,
    required int homeScore,
    required int awayScore,
  }) async {
    await _firestore.collection('matches').doc(matchId).update({
      'realHomeScore': homeScore,
      'realAwayScore': awayScore,
      'status': 'FINISHED',
    });
  }

  Future<void> updateMatchScoresBatch(List<Map<String, dynamic>> results) async {
    final batch = _firestore.batch();
    for (final r in results) {
      final ref = _firestore.collection('matches').doc(r['matchId'] as String);
      batch.update(ref, {
        'realHomeScore': r['homeScore'],
        'realAwayScore': r['awayScore'],
        'status': 'FINISHED',
      });
    }
    await batch.commit();
  }

  // Verificar si la polla aún puede recibir apuestas
  Future<bool> canBetOnPolla(String pollaId) async {
    try {
      final firstMatch = await getFirstMatchByPolla(pollaId);
      if (firstMatch == null) return false;

      // ✅ Comparar hora Colombia vs hora Colombia
      final nowColombia = DateTime.now(); // Hora local del dispositivo (Colombia)
      return nowColombia.isBefore(firstMatch.dateTime);
    } catch (e) {
      print('Error checking if can bet: $e');
      return false;
    }
  }
}