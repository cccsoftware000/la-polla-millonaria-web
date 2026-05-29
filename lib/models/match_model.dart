import 'package:cloud_firestore/cloud_firestore.dart';

class MatchModel {
  final String id;
  final String pollaId;
  final String local;
  final String visitor;
  final String localLogo;
  final String visitorLogo;
  final DateTime dateTime;
  final int? realHomeScore;
  final int? realAwayScore;
  final String status; // UPCOMING, LIVE, FINISHED
  final int? apiFixtureId;

  MatchModel({
    required this.id,
    required this.pollaId,
    required this.local,
    required this.visitor,
    required this.localLogo,
    required this.visitorLogo,
    required this.dateTime,
    this.realHomeScore,
    this.realAwayScore,
    this.status = 'UPCOMING',
    this.apiFixtureId,

  });

  factory MatchModel.fromMap(String id, Map<String, dynamic> map) {
    return MatchModel(
      id: id,
      pollaId: map['pollaId'] ?? '',
      local: map['local'] ?? '',
      visitor: map['visitor'] ?? '',
      localLogo: map['localLogo'] ?? '',
      visitorLogo: map['visitorLogo'] ?? '',
      dateTime: (map['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      realHomeScore: map['realHomeScore'],
      realAwayScore: map['realAwayScore'],
      status: map['status'] ?? 'UPCOMING',
      apiFixtureId: map['apiFixtureId'], // ✅ NUEVO
    );
  }

  // ✅ CORREGIDO - GETTER no necesita paréntesis
  bool get hasRealResult => realHomeScore != null && realAwayScore != null;

  bool get isFinished => status == 'FINISHED';
}