// lib/models/accumulated_history_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AccumulatedHistory {
  final String id;
  final String? betId;
  final String? pollaId;
  final int increment;
  final int previousAccumulated;
  final int newAccumulated;
  final int? pendingAccumulated;
  final DateTime timestamp;

  AccumulatedHistory({
    required this.id,
    this.betId,
    this.pollaId,
    required this.increment,
    required this.previousAccumulated,
    required this.newAccumulated,
    this.pendingAccumulated,
    required this.timestamp,
  });

  factory AccumulatedHistory.fromMap(String id, Map<String, dynamic> map) {
    return AccumulatedHistory(
      id: id,
      betId: map['betId'],
      pollaId: map['pollaId'],
      increment: map['increment'] ?? 0,
      previousAccumulated: map['previousAccumulated'] ?? 0,
      newAccumulated: map['newAccumulated'] ?? 0,
      pendingAccumulated: map['pendingAccumulated'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'betId': betId,
      'pollaId': pollaId,
      'increment': increment,
      'previousAccumulated': previousAccumulated,
      'newAccumulated': newAccumulated,
      'pendingAccumulated': pendingAccumulated,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  // ✅ Getter para saber si fue un pago de apuesta o un rollover
  bool get isBetPayment => betId != null && betId!.isNotEmpty;
  bool get isRollover => betId == null && pendingAccumulated != null;
}