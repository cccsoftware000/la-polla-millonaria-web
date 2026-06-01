import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MatchConstants {
  static final Map<String, List<Map<String, dynamic>>> _matchesByPolla = {};
  static String? _currentPollaId;

  static void setMatches(List<Map<String, dynamic>> matches, {String? pollaId}) {
    final key = pollaId ?? _currentPollaId ?? '_default';
    _matchesByPolla[key] = matches.map((match) {
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
        'dateTime': dateTime,
        'realHomeScore': match['realHomeScore'],
        'realAwayScore': match['realAwayScore'],
      };
    }).toList();
    _currentPollaId = key;
  }

  static List<Map<String, dynamic>> _getMatches({String? pollaId}) {
    final key = pollaId ?? _currentPollaId ?? '_default';
    return _matchesByPolla[key] ?? [];
  }

  static List<Map<String, dynamic>> getAllMatches({String? pollaId}) {
    return _getMatches(pollaId: pollaId);
  }

  static int getMatchCount({String? pollaId}) {
    return _getMatches(pollaId: pollaId).length;
  }

  static Map<String, dynamic> getMatchByIndex(int index, {String? pollaId}) {
    final matches = _getMatches(pollaId: pollaId);
    if (index < matches.length) {
      return matches[index];
    }
    return matches.isEmpty ? {} : matches[0];
  }

  static String? getCurrentPollaId() => _currentPollaId;

  static void clear({String? pollaId}) {
    if (pollaId != null) {
      _matchesByPolla.remove(pollaId);
      if (_currentPollaId == pollaId) {
        _currentPollaId = _matchesByPolla.keys.isNotEmpty ? _matchesByPolla.keys.last : null;
      }
    } else {
      _matchesByPolla.clear();
      _currentPollaId = null;
    }
  }

  // ==================== METODOS DE TIEMPO ====================

  static Duration getRemainingTime(int index, {String? pollaId}) {
    final matches = _getMatches(pollaId: pollaId);
    if (index >= matches.length) return Duration.zero;

    final match = matches[index];
    final matchDateTime = match['dateTime'] as DateTime;
    final now = DateTime.now();

    if (now.isAfter(matchDateTime)) {
      return Duration.zero;
    }

    return matchDateTime.difference(now);
  }

  static String getFormattedRemainingTime(int index, {String? pollaId}) {
    final remaining = getRemainingTime(index, pollaId: pollaId);

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

  static bool isMatchClosed(int index, {String? pollaId}) {
    return getRemainingTime(index, pollaId: pollaId) <= Duration.zero;
  }

  static bool areAllMatchesClosed({String? pollaId}) {
    final matches = _getMatches(pollaId: pollaId);
    for (int i = 0; i < matches.length; i++) {
      if (!isMatchClosed(i, pollaId: pollaId)) {
        return false;
      }
    }
    return true;
  }

  static DateTime? getNearestClosingDate({String? pollaId}) {
    final matches = _getMatches(pollaId: pollaId);
    DateTime? nearest;

    for (final match in matches) {
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

  static String getGlobalCountdown({String? pollaId}) {
    final nearest = getNearestClosingDate(pollaId: pollaId);

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
      case 'CONMEBOL Libertadores':
        badgeColor = Colors.green;
        break;
      case 'CONMEBOL Sudamericana':
        badgeColor = Colors.blue;
        break;
      case 'UEFA Champions League':
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
