import 'package:cloud_firestore/cloud_firestore.dart';

class PollaModel {
  final String id;
  final String name;
  final String status; // UPCOMING, ACTIVE, CLOSED, FINISHED, CANCELLED
  final DateTime startDate;
  final DateTime endDate;
  final int prizeAmount;
  final List<String> winnerIds;
  final int winnerCount;
  final int winnerPrize;
  final DateTime? createdAt;
  final DateTime? closedAt; // ✅ Agregar este campo


  PollaModel({
    required this.id,
    required this.name,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.prizeAmount,
    this.winnerIds = const [],
    this.winnerCount = 0,
    this.winnerPrize = 0,
    this.createdAt,
    this.closedAt,
  });

  factory PollaModel.fromMap(String id, Map<String, dynamic> map) {
    return PollaModel(
      id: id,
      name: map['name'] ?? '',
      status: map['status'] ?? 'UPCOMING',
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      prizeAmount: map['prizeAmount'] ?? 100000,
      winnerIds: List<String>.from(map['winnerIds'] ?? []),
      winnerCount: map['winnerCount'] ?? 0,
      winnerPrize: map['winnerPrize'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      closedAt: (map['closedAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isUpcoming => status == 'UPCOMING';
  bool get isActive => status == 'ACTIVE';
  bool get isClosed => closedAt != null || status != 'ACTIVE';
  bool get isFinished => status == 'FINISHED';
  bool get isCancelled => status == 'CANCELLED';

  bool get canBet => isActive && DateTime.now().isBefore(endDate);
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'startDate': startDate,
      'endDate': endDate,
      'prizeAmount': prizeAmount,
      'winnerIds': winnerIds,
      'winnerCount': winnerCount,
      'winnerPrize': winnerPrize,
      'createdAt': createdAt,
    };
  }
}