import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';

class MatchConstants {
  static List<Map<String, dynamic>> _matches = [];
  static String? _currentPollaId;

  static void setMatches(List<Map<String, dynamic>> matches, {String? pollaId}) {
    _matches = matches.map((match) {
      DateTime dateTime;
      if (match['dateTime'] is Timestamp) {
        dateTime = (match['dateTime'] as Timestamp).toDate();
      } else if (match['dateTime'] is DateTime) {
        dateTime = match['dateTime'] as DateTime;
      } else {
        dateTime = DateTime.now();
      }

      return {
        ...match,
        'dateTime': dateTime,  // Ya en hora Colombia
        'realHomeScore': match['realHomeScore'],
        'realAwayScore': match['realAwayScore'],
      };
    }).toList();
    _currentPollaId = pollaId;
  }

  static List<Map<String, dynamic>> getAllMatches() {
    return _matches;
  }

  static int getMatchCount() {
    return _matches.length;
  }

  static Map<String, dynamic> getMatchByIndex(int index) {
    if (index < _matches.length) {
      return _matches[index];
    }
    return _matches.isEmpty ? {} : _matches[0];
  }

  static String? getCurrentPollaId() => _currentPollaId;

  static void clear() {
    _matches = [];
    _currentPollaId = null;
  }

  // ==================== MÉTODOS DE TIEMPO ====================

  static Duration getRemainingTime(int index) {
    if (index >= _matches.length) return Duration.zero;

    final match = _matches[index];
    final matchDateTime = match['dateTime'] as DateTime; // ✅ Hora Colombia
    final now = DateTime.now(); // ✅ Hora local del dispositivo (Colombia si configurado)

    if (now.isAfter(matchDateTime)) {
      return Duration.zero;
    }

    return matchDateTime.difference(now);
  }

  static String getFormattedRemainingTime(int index) {
    final remaining = getRemainingTime(index);

    if (remaining <= Duration.zero) {
      return "Cerrado";
    }

    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);

    if (days > 0) {
      return "$days d ${hours}h";
    } else if (hours > 0) {
      return "${hours}h ${minutes}m";
    } else {
      return "${minutes}m";
    }
  }

  static bool isMatchClosed(int index) {
    return getRemainingTime(index) <= Duration.zero;
  }

  static bool areAllMatchesClosed() {
    for (int i = 0; i < _matches.length; i++) {
      if (!isMatchClosed(i)) {
        return false;
      }
    }
    return true;
  }

  static DateTime? getNearestClosingDate() {
    DateTime? nearest;

    for (int i = 0; i < _matches.length; i++) {
      final match = _matches[i];
      final matchDateTime = match['dateTime'] as DateTime;
      final now = DateTime.now();

      if (matchDateTime.isAfter(now)) {
        if (nearest == null || matchDateTime.isBefore(nearest)) {
          nearest = matchDateTime;
        }
      }
    }

    return nearest;
  }

  static String getGlobalCountdown() {
    final nearest = getNearestClosingDate();

    if (nearest == null) {
      return "Torneo finalizado";
    }

    final now = DateTime.now();
    final remaining = nearest.difference(now);

    if (remaining <= Duration.zero) {
      return "Cerrando...";
    }

    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);

    if (days > 0) {
      return "${days}d ${hours}h ${minutes}m";
    } else if (hours > 0) {
      return "${hours}h ${minutes}m";
    } else {
      return "${minutes}m";
    }
  }

  // ==================== WIDGETS UI ====================

  // En matches_constants.dart (ya lo tienes, pero asegúrate)
  static Widget buildTeamLogo(String assetPath, String emoji, double size) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              emoji,
              style: TextStyle(fontSize: size * 0.6),
            ),
          ),
        );
      },
    );
  }

  static Widget buildTournamentBadge(String tournament) {
    Color badgeColor;
    switch (tournament) {
      case '🌎 CONMEBOL Libertadores':
        badgeColor = Colors.green;
        break;
      case '🏆 CONMEBOL Sudamericana':
        badgeColor = Colors.blue;
        break;
      case '🏆 UEFA Champions League':
        badgeColor = Colors.purple;
        break;
      default:
        badgeColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, color: badgeColor, size: 12),
          const SizedBox(width: 4),
          Text(
            tournament,
            style: TextStyle(
              color: badgeColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}