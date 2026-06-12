// lib/screens/profile/bet_history_screen.dart
import 'package:flutter/material.dart';
import '../../core/constants/bet_status.dart';
import '../../core/constants/matches_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/bet_status_helper.dart';
import '../../core/utils/team_name_utils.dart';
import '../../models/bet_model.dart';
import '../../services/bet_service.dart';
import '../../services/match_service.dart';
import '../bet/bet_detail_screen.dart';

class BetHistoryScreen extends StatefulWidget {
  const BetHistoryScreen({super.key});

  @override
  State<BetHistoryScreen> createState() => _BetHistoryScreenState();
}

class _BetHistoryScreenState extends State<BetHistoryScreen> {
  final BetService _betService = BetService();
  final MatchService _matchService = MatchService();

  List<BetModel> _bets = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'TODAS';

  final List<String> _filters = ['TODAS', 'PENDIENTES', 'ACTIVAS', 'GANADAS', 'FINALIZADAS'];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allBets = await _betService.getUserBets();

      // Precargar partidos de todas las pollas con apuestas
      final pollaIds = allBets.map((b) => b.pollaId).toSet();
      for (final pid in pollaIds) {
        try {
          if (MatchConstants.getAllMatches(pollaId: pid).isNotEmpty) continue;
          final matches = await _matchService.getMatchesForBetScreen(pid);
          if (matches.isNotEmpty) {
            MatchConstants.setMatches(matches, pollaId: pid);
          }
        } catch (_) {}
      }

      setState(() {
        _bets = allBets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar historial: $e';
        _isLoading = false;
      });
    }
  }

  List<BetModel> get _filteredBets {
    if (_selectedFilter == 'TODAS') return _bets;
    if (_selectedFilter == 'PENDIENTES') {
      return _bets.where((b) => b.status == BetStatus.pendingPayment).toList();
    }
    if (_selectedFilter == 'ACTIVAS') {
      return _bets.where((b) => b.status == BetStatus.active).toList();
    }
    if (_selectedFilter == 'GANADAS') {
      return _bets.where((b) => b.status == BetStatus.winner).toList();
    }
    if (_selectedFilter == 'FINALIZADAS') {
      return _bets.where((b) => b.status == BetStatus.completed).toList();
    }
    return _bets;
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
          'HISTORIAL',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: AppColors.primaryPurple),
      )
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
              ),
              child: const Text('REINTENTAR'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Filtros
          _buildFilters(),
          const SizedBox(height: 16),
          // Lista de apuestas
          Expanded(
            child: _filteredBets.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('📭', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text(
                    'No hay apuestas en esta categoría',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredBets.length,
              itemBuilder: (context, index) {
                return _buildHistoryCard(_filteredBets[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: isSelected
                    ? const LinearGradient(
                  colors: [AppColors.primaryPurple, AppColors.energeticRed],
                )
                    : null,
                color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(BetModel bet) {
    final statusText = BetStatusHelper.getText(bet.status);
    final statusColor = BetStatusHelper.getColor(bet.status);
    final statusIcon = BetStatusHelper.getIcon(bet.status);

    // Calcular aciertos en tiempo real
    int correctCount = 0;
    int totalFinished = 0;

    for (int i = 0; i < bet.predictions.length; i++) {
      final prediction = bet.predictions[i];
      final match = MatchConstants.getMatchByIndex(i, pollaId: bet.pollaId);

      if (match['realHomeScore'] != null && match['realAwayScore'] != null) {
        totalFinished++;
        if (prediction['homeScore'] == match['realHomeScore'] &&
            prediction['awayScore'] == match['realAwayScore']) {
          correctCount++;
        }
      }
    }

    final date = bet.createdAt?.toDate();
    final formattedDate = date != null
        ? '${date.day}/${date.month}/${date.year}'
        : 'Fecha no disponible';

    // Mostrar primeros 3 partidos
    final displayedPredictions = bet.predictions.take(3).toList();
    final remainingCount = bet.predictions.length - 3;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BetDetailScreen(bet: bet),
          ),
        ).then((_) => _loadHistory());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.06),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
          border: Border.all(
            color: bet.status == BetStatus.winner
                ? Colors.greenAccent.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(statusIcon, color: statusColor, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Predicciones
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: displayedPredictions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final prediction = entry.value;
                    final match = MatchConstants.getMatchByIndex(index, pollaId: bet.pollaId);
                    final isLast = index == displayedPredictions.length - 1;

                    final hasRealResult = match['realHomeScore'] != null && match['realAwayScore'] != null;
                    final isCorrect = hasRealResult &&
                        prediction['homeScore'] == match['realHomeScore'] &&
                        prediction['awayScore'] == match['realAwayScore'];

                    return Row(
                      children: [
                        Container(
                          width: 90,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? Colors.green.withValues(alpha: 0.1)
                                : (hasRealResult && !isCorrect
                                ? Colors.red.withValues(alpha: 0.05)
                                : Colors.white.withValues(alpha: 0.03)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCorrect
                                  ? Colors.greenAccent.withValues(alpha: 0.3)
                                  : (hasRealResult && !isCorrect
                                  ? Colors.redAccent.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.08)),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      TeamNameUtils.getShortName(match['local'] ?? ''),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 8,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryPurple.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${prediction['homeScore']}-${prediction['awayScore']}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      TeamNameUtils.getShortName(match['visitor'] ?? ''),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 8,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                              if (hasRealResult)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Icon(
                                    isCorrect ? Icons.check_circle : Icons.cancel,
                                    size: 10,
                                    color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(
                              Icons.chevron_right,
                              size: 12,
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),

              // Indicador de más partidos
              if (remainingCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text(
                      '+$remainingCount partidos más',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),

              // Resumen de aciertos
              if (totalFinished > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: correctCount == totalFinished
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Aciertos: $correctCount / $totalFinished',
                          style: TextStyle(
                            color: correctCount == totalFinished
                                ? Colors.greenAccent
                                : Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Premio si es ganadora
              if (bet.status == BetStatus.winner && bet.prize != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.greenAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.greenAccent, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '+ \$${bet.prize!.toInt().toString()}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}