// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String phone;
  final String name;
  final String avatar;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;
  final bool pushNotificationsEnabled;
  final int totalBetsPaid;      // Apuestas pagadas (confirmadas)
  final int totalBetsWon;       // Apuestas ganadoras
  final int experiencePoints;   // Puntos de experiencia totales
  final int level;              // Nivel actual (1-10)

  UserModel({
    required this.uid,
    required this.phone,
    required this.name,
    required this.avatar,
    this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
    this.pushNotificationsEnabled = true,
    this.totalBetsPaid = 0,
    this.totalBetsWon = 0,
    this.experiencePoints = 0,
    this.level = 1,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      phone: map['phone'] ?? '',
      name: map['name'] ?? '',
      avatar: map['avatar'] ?? '⚽',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (map['lastLoginAt'] as Timestamp?)?.toDate(),
      isActive: map['isActive'] ?? true,
      pushNotificationsEnabled: map['pushNotificationsEnabled'] ?? true,
      totalBetsPaid: map['totalBetsPaid'] ?? 0,
      totalBetsWon: map['totalBetsWon'] ?? 0,
      experiencePoints: map['experiencePoints'] ?? 0,
      level: map['level'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phone': phone,
      'name': name,
      'avatar': avatar,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'isActive': isActive,
      'pushNotificationsEnabled': pushNotificationsEnabled,
      'totalBetsPaid': totalBetsPaid,
      'totalBetsWon': totalBetsWon,
      'experiencePoints': experiencePoints,
      'level': level,
    };
  }

  // ✅ Método para obtener iniciales del nombre
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  // ✅ Getter para el título del nivel
  String get levelTitle {
    switch (level) {
      case 1: return 'Principiante';
      case 2: return 'Aprendiz';
      case 3: return 'Aficionado';
      case 4: return 'Conocedor';
      case 5: return 'Experto';
      case 6: return 'Veterano';
      case 7: return 'Maestro';
      case 8: return 'Leyenda';
      case 9: return 'Mítico';
      case 10: return 'Dios del Fútbol';
      default: return 'Principiante';
    }
  }

  // ✅ Getter para el porcentaje hacia el próximo nivel
  double get nextLevelProgress {
    final expForCurrent = _getExpRequiredForLevel(level);
    final expForNext = _getExpRequiredForLevel(level + 1);
    final currentExp = experiencePoints - expForCurrent;
    final requiredExp = expForNext - expForCurrent;
    if (requiredExp <= 0) return 1.0;
    return (currentExp / requiredExp).clamp(0.0, 1.0);
  }

  // ✅ XP requerida para cada nivel
  int _getExpRequiredForLevel(int level) {
    switch (level) {
      case 1: return 0;
      case 2: return 100;
      case 3: return 250;
      case 4: return 500;
      case 5: return 1000;
      case 6: return 2000;
      case 7: return 3500;
      case 8: return 5500;
      case 9: return 8000;
      case 10: return 12000;
      default: return 0;
    }
  }

  // ✅ XP que falta para el próximo nivel
  int get expToNextLevel {
    final requiredForNext = _getExpRequiredForLevel(level + 1);
    return requiredForNext - experiencePoints;
  }
}