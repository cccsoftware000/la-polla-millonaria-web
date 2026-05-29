// lib/screens/results/results_screen.dart
import 'package:flutter/material.dart';
import '../../core/constants/matches_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  List<Map<String, dynamic>> _matches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _matches = List.from(MatchConstants.getAllMatches());
    setState(() => _isLoading = false);
  }

  String _getScoreText(Map<String, dynamic> match) {
    // ✅ Usar resultados de Firestore
    if (match['realHomeScore'] != null && match['realAwayScore'] != null) {
      return '${match['realHomeScore']} - ${match['realAwayScore']}';
    }
    return 'VS';
  }

  String _getMatchStatus(Map<String, dynamic> match) {
    // ✅ Estado basado en Firestore
    if (match['realHomeScore'] != null && match['realAwayScore'] != null) {
      return 'FT';
    }
    return 'UPCOMING';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'FT':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'FT':
        return 'FINALIZADO';
      default:
        return 'POR JUGAR';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'RESULTADOS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: AppColors.primaryPurple),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _matches.length,
        itemBuilder: (context, index) {
          final match = _matches[index];
          final status = _getMatchStatus(match);
          final statusColor = _getStatusColor(status);
          final statusText = _getStatusText(status);
          final scoreText = _getScoreText(match);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                // Torneo y fecha
                Row(
                  children: [
                    if (match['tournament'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          match['tournament'],
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      DateUtilsApp.formatMatchDateTime(match['dateTime']),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Equipos y marcador
                Row(
                  children: [
                    // Equipo Local
                    Expanded(
                      child: Column(
                        children: [
                          MatchConstants.buildTeamLogo(
                            match['localLogo'] ?? '⚽',
                            match['localEmoji'] ?? '⚽',
                            50,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            match['local'] ?? 'Local',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    // Marcador
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: status == 'FT'
                            ? Colors.green.withValues(alpha: 0.2)
                            : AppColors.primaryPurple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            scoreText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Equipo Visitante
                    Expanded(
                      child: Column(
                        children: [
                          MatchConstants.buildTeamLogo(
                            match['visitorLogo'] ?? '⚽',
                            match['visitorEmoji'] ?? '⚽',
                            50,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            match['visitor'] ?? 'Visitante',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}