// lib/models/bet_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class BetModel {
  final String uid;
  final String pollaId;
  final String? pollaName;
  final String status;
  final List<Map<String, dynamic>> predictions;
  final bool paymentConfirmed;
  final int exactHits;
  final String id;
  final Timestamp? createdAt;
  final bool deleted;  // Soft delete flag
  final Timestamp? deletedAt;  // Cuándo se marcó
  final double? prize;


  BetModel({
    required this.uid,
    required this.pollaId,
    required this.status,
    required this.predictions,
    required this.paymentConfirmed,
    required this.id,
    this.createdAt,
    this.exactHits = 0,
    this.deleted = false,
    this.deletedAt,
    this.pollaName,
    this.prize,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'pollaId': pollaId,
      'status': status,
      'predictions': predictions,
      'paymentConfirmed': paymentConfirmed,
      'exactHits': exactHits,
      'deleted': deleted,
      'deletedAt': deletedAt,
      'createdAt': createdAt,
      'pollaName': pollaName,
      'prize': prize,
    };
  }

  factory BetModel.fromMap(String id, Map<String, dynamic> map) {
    return BetModel(
      id: id,
      uid: map['uid'] ?? '',
      pollaId: map['pollaId'] ?? '',
      pollaName: map['pollaName'],
      status: map['status'] ?? '',
      predictions: List<Map<String, dynamic>>.from(map['predictions'] ?? []),
      paymentConfirmed: map['paymentConfirmed'] ?? false,
      exactHits: map['exactHits'] ?? 0,
      createdAt: map['createdAt'],
      deleted: map['deleted'] ?? false,
      deletedAt: map['deletedAt'],
      prize: map['prize']?.toDouble(),
    );
  }

}