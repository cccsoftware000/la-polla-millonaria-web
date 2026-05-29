import 'package:cloud_firestore/cloud_firestore.dart';

class GlobalSettingsModel {
  final int betPrice;
  final int accumulatedPercentage;
  final int currentAccumulated;
  final int lastAccumulatedIncrease;
  final DateTime lastAccumulatedUpdate;

  GlobalSettingsModel({
    required this.betPrice,
    required this.accumulatedPercentage,
    required this.currentAccumulated,
    required this.lastAccumulatedIncrease,
    required this.lastAccumulatedUpdate,
  });

  factory GlobalSettingsModel.fromMap(Map<String, dynamic> map) {
    return GlobalSettingsModel(
      betPrice: map['betPrice'] ?? 5000,
      accumulatedPercentage: map['accumulatedPercentage'] ?? 60,
      currentAccumulated: map['currentAccumulated'] ?? 0,
      lastAccumulatedIncrease: map['lastAccumulatedIncrease'] ?? 0,
      lastAccumulatedUpdate: (map['lastAccumulatedUpdate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'betPrice': betPrice,
      'accumulatedPercentage': accumulatedPercentage,
      'currentAccumulated': currentAccumulated,
      'lastAccumulatedIncrease': lastAccumulatedIncrease,
      'lastAccumulatedUpdate': Timestamp.fromDate(lastAccumulatedUpdate),
    };
  }

  int getIncreaseForBet() {
    final increment = (betPrice * accumulatedPercentage / 100).floor();
    return increment;
  }
}