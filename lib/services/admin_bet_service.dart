// lib/services/admin_bet_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bet_model.dart';

class AdminBetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtener apuestas por jornada (para admin)
  Future<List<BetModel>> getBetsByJornada(String pollaId) async {
    try {
      final snapshot = await _firestore
          .collection('bets')
          .where('pollaId', isEqualTo: pollaId)
          .where('deleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      print('📊 Apuestas encontradas: ${snapshot.docs.length}');

      return snapshot.docs.map((doc) {
        return BetModel.fromMap(doc.id, doc.data());
      }).toList();
    } on FirebaseException catch (e) {
      print('❌ Error getting bets by jornada: ${e.code} - ${e.message}');
      return [];
    } catch (e) {
      print('❌ Error getting bets by jornada: $e');
      return [];
    }
  }

  /// Obtener todas las apuestas (para ranking completo)
  Future<List<BetModel>> getAllBets() async {
    try {
      final snapshot = await _firestore
          .collection('bets')
          .where('deleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return BetModel.fromMap(doc.id, doc.data());
      }).toList();
    } catch (e) {
      print('Error getting all bets: $e');
      return [];
    }
  }
}