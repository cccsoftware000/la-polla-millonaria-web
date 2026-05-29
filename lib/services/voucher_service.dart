import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/voucher_model.dart';

class VoucherService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _vouchersCollection = 'vouchers';

  // Redimir un vale
  Future<bool> redeemVoucher({
    required String code,
    required String userId,
    required String betId,
  }) async {
    try {
      print('🔍 Buscando vale: "${code.toUpperCase()}"');

      final snapshot = await _firestore
          .collection(_vouchersCollection)
          .where('code', isEqualTo: code.toUpperCase())
          .where('used', isEqualTo: false)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('❌ Vale no encontrado o ya usado');
        return false;
      }

      final voucherDoc = snapshot.docs.first;
      final voucherData = voucherDoc.data();
      print('✅ Vale encontrado: ${voucherData['code']}');
      print('   amount: ${voucherData['amount']}');

      // Verificar expiración
      final expiresAt = (voucherData['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        print('❌ Vale expirado: ${expiresAt}');
        return false;
      }

      print('🔄 Iniciando transacción...');

      // ✅ CORRECCIÓN: Primero hacer todas las lecturas, luego las escrituras
      final betRef = _firestore.collection('bets').doc(betId);

      await _firestore.runTransaction((transaction) async {
        // ✅ 1. PRIMERO leer el documento de la apuesta
        final betDoc = await transaction.get(betRef);

        if (!betDoc.exists) {
          print('❌ Apuesta no encontrada: $betId');
          throw Exception('Apuesta no encontrada');
        }

        print('  ✅ Apuesta encontrada');

        // ✅ 2. AHORA SÍ hacer las escrituras (después de todas las lecturas)
        transaction.update(voucherDoc.reference, {
          'used': true,
          'usedBy': userId,
          'usedForBetId': betId,
          'usedAt': FieldValue.serverTimestamp(),
        });
        print('  ✅ Vale marcado como usado');

        transaction.update(betRef, {
          'paymentConfirmed': true,
          'paymentConfirmedAt': FieldValue.serverTimestamp(),
          'paymentMethod': 'voucher',
          'voucherId': voucherDoc.id,
          'voucherAmount': voucherData['amount'],
          'status': 'ACTIVE',
        });
        print('  ✅ Apuesta actualizada a ACTIVE');
      });

      print('✅ Transacción completada exitosamente');
      return true;
    } catch (e) {
      print('❌ Error redeeming voucher: $e');
      return false;
    }
  }

  // Obtener vales válidos de un usuario
  Future<List<VoucherModel>> getUserVouchers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_vouchersCollection)
          .where('used', isEqualTo: false)
          .where('expiresAt', isGreaterThan: DateTime.now())
          .get();

      return snapshot.docs.map((doc) {
        return VoucherModel.fromMap(doc.id, doc.data());
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Generar vales (solo admin)
  Future<void> generateVouchers({
    required int amount,
    required int count,
    required DateTime expiresAt,
  }) async {
    final batch = _firestore.batch();

    for (int i = 0; i < count; i++) {
      final code = _generateVoucherCode();
      final voucherRef = _firestore.collection(_vouchersCollection).doc();

      batch.set(voucherRef, {
        'code': code,
        'amount': amount,
        'used': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
      });
    }

    await batch.commit();
  }

  String _generateVoucherCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Generar parte aleatoria (10 caracteres)
    String randomPart = '';
    for (int i = 0; i < 10; i++) {
      randomPart += chars[random.nextInt(chars.length)];
    }

    // Añadir timestamp en base36
    String timestampPart = timestamp.toRadixString(36).toUpperCase().padLeft(6, '0');

    // Calcular checksum (primer caracter del hash)
    final checksumInput = '$randomPart$timestampPart';
    final checksum = _calculateChecksum(checksumInput);

    // Formato final: XXXX-XXXX-XX-XXXX-XX (5 grupos)
    final parts = [
      randomPart.substring(0, 4),
      randomPart.substring(4, 8),
      randomPart.substring(8, 10),
      timestampPart.substring(0, 4),
      timestampPart.substring(4, 6),
      checksum,
    ];

    return parts.join('-');
  }

  String _calculateChecksum(String input) {
    int sum = 0;
    for (int i = 0; i < input.length; i++) {
      sum += input.codeUnitAt(i);
    }
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789';
    return chars[sum % chars.length];
  }
}