import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/bet_status.dart';
import '../models/bet_model.dart';

class BetService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final String _betsCollection = 'bets';

  User? get _currentUser => auth.currentUser;

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'unauthenticated':
        return 'Usuario no autenticado';
      case 'permission-denied':
        return 'No tienes permiso para realizar esta acción';
      case 'not-found':
        return 'Apuesta no encontrada';
      case 'network-error':
        return 'Error de conexión. Verifica tu internet';
      default:
        return 'Error inesperado. Intenta nuevamente';
    }
  }

  Future<void> createBet({
    required List<Map<String, dynamic>> predictions,
    required String pollaId,
  }) async {
    try {
      final user = _currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 2));

      final bet = BetModel(
        uid: user.uid,
        status: BetStatus.pendingPayment,
        predictions: predictions,
        paymentConfirmed: false,
        pollaId: pollaId,
        id: '',
        createdAt: null,
      );

      await firestore.collection(_betsCollection).add({
        ...bet.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
      });
    } on FirebaseException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception('Error al crear la apuesta: $e');
    }
  }

  Future<void> updateBet({
    required String betId,
    required List<Map<String, dynamic>> predictions,
  }) async {
    try {
      final user = _currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final betRef = firestore.collection(_betsCollection).doc(betId);
      final betDoc = await betRef.get();

      if (!betDoc.exists) {
        throw Exception('Apuesta no encontrada');
      }

      final betData = betDoc.data() as Map<String, dynamic>?;
      if (betData?['uid'] != user.uid) {
        throw Exception('No tienes permiso para editar esta apuesta');
      }

      final status = betData?['status'];
      if (status != BetStatus.pendingPayment) {
        throw Exception('Solo se pueden editar apuestas pendientes de pago');
      }

      await betRef.update({
        'predictions': predictions,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception('Error al actualizar la apuesta: $e');
    }
  }

  Future<void> deleteBet(String betId) async {
    try {
      final user = _currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final betRef = firestore.collection(_betsCollection).doc(betId);
      final betDoc = await betRef.get();

      if (!betDoc.exists) throw Exception('Apuesta no encontrada');
      if (betDoc.data()?['uid'] != user.uid) throw Exception('No tienes permiso');

      // ✅ Solo marcar como eliminada (MUCHO más barato que delete)
      await betRef.update({
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al eliminar la apuesta: $e');
    }
  }

  Future<int> getPendingBetsCount() async {
    try {
      final user = _currentUser;
      if (user == null) return 0;

      final snapshot = await firestore
          .collection(_betsCollection)
          .where('uid', isEqualTo: user.uid)
          .where('status', isEqualTo: BetStatus.pendingPayment)
          .where('deleted', isEqualTo: false)  // 👈 No contar eliminadas
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getPendingBets() async {
    return await getPendingBetsCount();
  }

  Future<List<BetModel>> getUserBets() async {
    try {
      final user = _currentUser;
      if (user == null) return [];

      final snapshot = await firestore
          .collection(_betsCollection)
          .where('uid', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return null;
        // ✅ Filtrar en memoria
        if (data['deleted'] == true) return null;
        return BetModel.fromMap(doc.id, data);
      }).whereType<BetModel>().toList();
    } catch (e) {
      print('Error getting user bets: $e');
      return [];
    }
  }

  Future<BetModel?> getBetById(String betId) async {
    try {
      final user = _currentUser;
      if (user == null) return null;

      final doc = await firestore.collection(_betsCollection).doc(betId).get();

      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      if (data['uid'] != user.uid) return null;

      return BetModel.fromMap(doc.id, data);
    } on FirebaseException catch (e) {
      print('Error getting bet by id: ${e.code}');
      return null;
    } catch (e) {
      print('Error inesperado: $e');
      return null;
    }
  }

  Future<bool> isBetEditable(String betId) async {
    try {
      final user = _currentUser;
      if (user == null) return false;

      final doc = await firestore.collection(_betsCollection).doc(betId).get();

      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>?;
      return data?['uid'] == user.uid && data?['status'] == BetStatus.pendingPayment;
    } catch (e) {
      return false;
    }
  }

  Future<void> updateBetStatus({
    required String betId,
    required String status,
  }) async {
    try {
      final user = _currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final betRef = firestore.collection(_betsCollection).doc(betId);
      final betDoc = await betRef.get();

      if (!betDoc.exists) {
        throw Exception('Apuesta no encontrada');
      }

      final betData = betDoc.data() as Map<String, dynamic>?;
      if (betData?['uid'] != user.uid) {
        throw Exception('No tienes permiso');
      }

      await betRef.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception('Error al actualizar el estado: $e');
    }
  }

  Future<void> confirmPayment(String betId) async {
    try {
      await updateBetStatus(betId: betId, status: BetStatus.active);
    } catch (e) {
      throw Exception('Error al confirmar el pago: $e');
    }
  }

  Future<void> cancelBet(String betId) async {
    try {
      await updateBetStatus(betId: betId, status: BetStatus.cancelled);
    } catch (e) {
      throw Exception('Error al cancelar la apuesta: $e');
    }
  }

  Future<List<BetModel>> getActiveBets() async {
    try {
      final user = _currentUser;
      if (user == null) return [];

      final snapshot = await firestore
          .collection(_betsCollection)
          .where('uid', isEqualTo: user.uid)
          .where('status', isEqualTo: BetStatus.active)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return null;
        return BetModel.fromMap(doc.id, data);
      }).whereType<BetModel>().toList();
    } catch (e) {
      print('Error getting active bets: $e');
      return [];
    }
  }

  Future<List<BetModel>> getWinnerBets() async {
    try {
      final user = _currentUser;
      if (user == null) return [];

      final snapshot = await firestore
          .collection(_betsCollection)
          .where('uid', isEqualTo: user.uid)
          .where('status', isEqualTo: BetStatus.winner)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return null;
        return BetModel.fromMap(doc.id, data);
      }).whereType<BetModel>().toList();
    } catch (e) {
      print('Error getting winner bets: $e');
      return [];
    }
  }

  Future<bool> hasPendingPaymentBets() async {
    try {
      final count = await getPendingBetsCount();
      return count > 0;
    } catch (e) {
      return false;
    }
  }

  Stream<List<BetModel>> streamUserBets() {
    final user = _currentUser;
    if (user == null) return Stream.value([]);

    return firestore
        .collection(_betsCollection)
        .where('uid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return null;
        return BetModel.fromMap(doc.id, data);
      }).whereType<BetModel>().toList();
    }).handleError((error) {
      print('Stream error: $error');
      return <BetModel>[];
    });
  }

  Stream<List<BetModel>> streamPendingBets() {
    final user = _currentUser;
    if (user == null) return Stream.value([]);

    return firestore
        .collection(_betsCollection)
        .where('uid', isEqualTo: user.uid)
        .where('status', isEqualTo: BetStatus.pendingPayment)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return null;
        return BetModel.fromMap(doc.id, data);
      }).whereType<BetModel>().toList();
    }).handleError((error) {
      print('Stream error: $error');
      return <BetModel>[];
    });
  }

  Future<void> confirmBetPayment(BetModel bet) async {
    try {
      final user = _currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      if (bet.uid != user.uid) {
        throw Exception('No tienes permiso para confirmar esta apuesta');
      }

      if (bet.status != BetStatus.pendingPayment) {
        throw Exception('Solo se pueden confirmar apuestas pendientes de pago');
      }

      if (bet.paymentConfirmed == true) {
        throw Exception('Esta apuesta ya fue confirmada');
      }

      // La Cloud Function onBetPaid es la unica responsable de incrementar el pozo.
      // Aqui solo marcamos paymentConfirmed; el backend valida si la polla sigue abierta.
      await firestore.collection(_betsCollection).doc(bet.id).update({
        'paymentConfirmed': true,
        'paymentConfirmedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al confirmar el pago: $e');
    }
  }


}
