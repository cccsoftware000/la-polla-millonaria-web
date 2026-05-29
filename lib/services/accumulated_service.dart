import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants/bet_status.dart';
import '../models/bet_model.dart';
import '../models/global_settings_model.dart';

class AccumulatedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Referencias a Firestore
  final String _settingsDocPath = 'settings/global';
  final String _betsCollection = 'bets';
  final String _accumulatedHistoryCollection = 'accumulated_history';

  // Stream para escuchar cambios en tiempo real
  Stream<GlobalSettingsModel> streamAccumulated() {
    return _firestore
        .doc(_settingsDocPath)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return GlobalSettingsModel.fromMap(doc.data()!);
      }
      return GlobalSettingsModel(
        betPrice: 5000,
        accumulatedPercentage: 60,
        currentAccumulated: 0,
        lastAccumulatedIncrease: 0,
        lastAccumulatedUpdate: DateTime.now(),
      );
    });
  }

  // Obtener configuración actual
  Future<GlobalSettingsModel> getCurrentSettings() async {
    final doc = await _firestore.doc(_settingsDocPath).get();
    if (doc.exists) {
      return GlobalSettingsModel.fromMap(doc.data()!);
    }
    return GlobalSettingsModel(
      betPrice: 5000,
      accumulatedPercentage: 60,
      currentAccumulated: 0,
      lastAccumulatedIncrease: 0,
      lastAccumulatedUpdate: DateTime.now(),
    );
  }

  // Incrementar acumulado cuando se confirma una apuesta
  Future<void> incrementAccumulatedForBet(BetModel bet) async {
    // Verificar que la apuesta está en estado PENDING_PAYMENT
    if (bet.status != BetStatus.pendingPayment) {
      throw Exception('Solo se pueden confirmar apuestas pendientes de pago');
    }

    // Verificar que no haya sido ya confirmada
    if (bet.paymentConfirmed == true) {
      throw Exception('Esta apuesta ya fue confirmada anteriormente');
    }

    final settings = await getCurrentSettings();
    final increment = settings.getIncreaseForBet();

    final docRef = _firestore.doc(_settingsDocPath);

    // Usar transacción para evitar inconsistencias
    await _firestore.runTransaction((transaction) async {
      final docSnapshot = await transaction.get(docRef);

      GlobalSettingsModel currentSettings;
      if (docSnapshot.exists) {
        currentSettings = GlobalSettingsModel.fromMap(docSnapshot.data()!);
      } else {
        currentSettings = GlobalSettingsModel(
          betPrice: 5000,
          accumulatedPercentage: 60,
          currentAccumulated: 0,
          lastAccumulatedIncrease: 0,
          lastAccumulatedUpdate: DateTime.now(),
        );
      }

      final newAccumulated = currentSettings.currentAccumulated + increment;

      // Actualizar configuración global
      transaction.update(docRef, {
        'currentAccumulated': newAccumulated,
        'lastAccumulatedIncrease': increment,
        'lastAccumulatedUpdate': FieldValue.serverTimestamp(),
      });

      // Registrar historial del incremento
      final historyRef = _firestore
          .collection(_accumulatedHistoryCollection)
          .doc();

      transaction.set(historyRef, {
        'betId': bet.id,
        'increment': increment,
        'previousAccumulated': currentSettings.currentAccumulated,
        'newAccumulated': newAccumulated,
        'timestamp': FieldValue.serverTimestamp(),
        'betPrice': currentSettings.betPrice,
        'percentage': currentSettings.accumulatedPercentage,
      });

      // Marcar la apuesta como confirmada
      final betRef = _firestore.collection(_betsCollection).doc(bet.id);
      transaction.update(betRef, {
        'paymentConfirmed': true,
        'paymentConfirmedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Actualizar precio de apuesta (solo admin)
  Future<void> updateBetPrice(int newPrice) async {
    if (newPrice <= 0) {
      throw Exception('El precio debe ser mayor a 0');
    }

    await _firestore.doc(_settingsDocPath).update({
      'betPrice': newPrice,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Actualizar porcentaje de acumulado (solo admin)
  Future<void> updateAccumulatedPercentage(int newPercentage) async {
    if (newPercentage < 0 || newPercentage > 100) {
      throw Exception('El porcentaje debe estar entre 0 y 100');
    }

    await _firestore.doc(_settingsDocPath).update({
      'accumulatedPercentage': newPercentage,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Inicializar configuración si no existe
  Future<void> initializeSettings() async {
    final doc = await _firestore.doc(_settingsDocPath).get();
    if (!doc.exists) {
      await _firestore.doc(_settingsDocPath).set({
        'betPrice': 5000,
        'accumulatedPercentage': 60,
        'currentAccumulated': 25000000,
        'lastAccumulatedIncrease': 0,
        'lastAccumulatedUpdate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Obtener historial de incrementos
  Future<List<Map<String, dynamic>>> getAccumulatedHistory({int limit = 10}) async {
    final snapshot = await _firestore
        .collection(_accumulatedHistoryCollection)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      return {
        ...doc.data(),
        'id': doc.id,
      };
    }).toList();
  }

  // Stream de historial reciente
  Stream<List<Map<String, dynamic>>> streamRecentHistory() {
    return _firestore
        .collection(_accumulatedHistoryCollection)
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          ...doc.data(),
          'id': doc.id,
        };
      }).toList();
    });
  }
}