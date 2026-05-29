import 'package:cloud_firestore/cloud_firestore.dart';

class VoucherModel {
  final String id;
  final String code;          // Código único del vale
  final int amount;           // Monto del vale (ej: 5000, 10000)
  final bool used;            // Ya fue usado?
  final String? usedBy;       // UID del usuario que lo usó
  final String? usedForBetId; // Apuesta que pagó
  final DateTime createdAt;
  final DateTime? usedAt;
  final DateTime expiresAt;   // Fecha de expiración

  VoucherModel({
    required this.id,
    required this.code,
    required this.amount,
    required this.used,
    this.usedBy,
    this.usedForBetId,
    required this.createdAt,
    this.usedAt,
    required this.expiresAt,
  });

  factory VoucherModel.fromMap(String id, Map<String, dynamic> map) {
    return VoucherModel(
      id: id,
      code: map['code'] ?? '',
      amount: map['amount'] ?? 0,
      used: map['used'] ?? false,
      usedBy: map['usedBy'],
      usedForBetId: map['usedForBetId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      usedAt: (map['usedAt'] as Timestamp?)?.toDate(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'amount': amount,
      'used': used,
      'usedBy': usedBy,
      'usedForBetId': usedForBetId,
      'createdAt': Timestamp.fromDate(createdAt),
      'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  bool get isValid => !used && DateTime.now().isBefore(expiresAt);
}