import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/bet_status.dart';
import '../../core/constants/matches_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/bet_model.dart';
import '../../services/bet_service.dart';
import '../../services/analytics_service.dart';

import '../../widgets/bet/bet_status_banner.dart';
import '../../widgets/bet/detail_info_chip.dart';

import '../../services/voucher_service.dart';
import 'bet_screen.dart';

class BetDetailScreen extends StatefulWidget {
  final BetModel bet;

  const BetDetailScreen({super.key, required this.bet});

  @override
  State<BetDetailScreen> createState() => _BetDetailScreenState();
}

class _BetDetailScreenState extends State<BetDetailScreen> {
  final BetService betService = BetService();
  bool isLoading = false;
  String _voucherCode = '';
  late BetModel currentBet;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    currentBet = widget.bet;

    // Timer para actualizar UI si la apuesta está pendiente (por si cambia estado)
    if (currentBet.status == BetStatus.pendingPayment) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _refreshBet();
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool get canEdit {
    return currentBet.status == BetStatus.pendingPayment;
  }

  Future<void> _refreshBet() async {
    final updatedBet = await betService.getBetById(currentBet.id);
    if (updatedBet != null && mounted) {
      setState(() {
        currentBet = updatedBet;
      });
    }
  }

  Future<void> _deleteBet() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text(
          'Eliminar apuesta',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '¿Estás seguro de que quieres eliminar esta apuesta? Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'ELIMINAR',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      isLoading = true;
    });

    try {
      await betService.deleteBet(currentBet.id);
      await AnalyticsService.logBetDeleted(betId: currentBet.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Apuesta eliminada correctamente'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdDate = currentBet.createdAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(currentBet.createdAt!.toDate())
        : 'Sin fecha';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              AppColors.primaryPurple,
              AppColors.midnightBlue,
              AppColors.background,
            ],
            stops: const [0.1, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryPurple,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshBet,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 30),
                        BetStatusBanner(
                          bet: currentBet,
                          onRefresh: () async {
                            print('🔄 Refrescando apuesta...');
                            await _refreshBet();
                            setState(() {}); // Forzar rebuild
                          },
                        ),
                        const SizedBox(height: 28),
                        _buildInfoChips(createdDate),
                        const SizedBox(height: 35),
                        _buildPredictionsTitle(),
                        const SizedBox(height: 18),
                        _buildPredictionsList(),
                        const SizedBox(height: 35),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Detalle apuesta',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '#${currentBet.id.substring(0, 6).toUpperCase()}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChips(String createdDate) {
    // Verificar cuántos partidos están cerrados
    int closedMatches = 0;
    for (int i = 0; i < currentBet.predictions.length; i++) {
      if (MatchConstants.isMatchClosed(i)) {
        closedMatches++;
      }
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        DetailInfoChip(
          icon: Icons.calendar_month,
          label: 'Fecha',
          value: createdDate,
        ),
        DetailInfoChip(
          icon: Icons.sports_soccer,
          label: 'Partidos',
          value: '${currentBet.predictions.length}',
        ),
        DetailInfoChip(
          icon: closedMatches > 0 ? Icons.lock : Icons.emoji_events,
          label: 'Estado',
          value: closedMatches > 0 ? '$closedMatches cerrados' : 'Activos',
          // 👇 ELIMINAR valueColor - no existe en DetailInfoChip
        ),
        DetailInfoChip(
          icon: Icons.access_time,
          label: 'Próximo cierre',
          value: MatchConstants.getGlobalCountdown(),
        ),
      ],
    );
  }

  Widget _buildPredictionsTitle() {
    return const Text(
      'PREDICCIONES',
      style: TextStyle(
        color: Colors.white70,
        fontSize: 15,
        letterSpacing: 2,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPredictionsList() {
    return Column(
      children: currentBet.predictions.asMap().entries.map((entry) {
        final index = entry.key;
        final prediction = entry.value;
        final match = MatchConstants.getMatchByIndex(index);
        final isClosed = MatchConstants.isMatchClosed(index);
        final remainingTime = MatchConstants.getFormattedRemainingTime(index);

        // ✅ Verificar si el partido tiene resultado real
        final hasRealResult = match['realHomeScore'] != null && match['realAwayScore'] != null;
        final isCorrect = hasRealResult ? _isPredictionCorrect(prediction, match) : false;

        // ✅ Obtener el resultado real para mostrar
        final realScoreText = hasRealResult
            ? '${match['realHomeScore']} - ${match['realAwayScore']}'
            : 'Pendiente';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isClosed
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCorrect && hasRealResult
                  ? Colors.green.withValues(alpha: 0.5)
                  : (isClosed
                  ? Colors.redAccent.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge del torneo
              if (match != null)
                MatchConstants.buildTournamentBadge(match["tournament"]),
              const SizedBox(height: 12),

              // Fecha y hora del partido
              if (match != null)
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      match["dateStr"],
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      match["time"],
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),

              // Tiempo restante o cerrado
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isClosed
                      ? Colors.redAccent.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isClosed ? Icons.lock : Icons.timer,
                      size: 12,
                      color: isClosed ? Colors.redAccent : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isClosed
                          ? "Partido cerrado"
                          : "Cierra en: $remainingTime",
                      style: TextStyle(
                        color: isClosed ? Colors.redAccent : Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Equipos y marcador
              Row(
                children: [
                  // Equipo Local
                  Expanded(
                    child: Column(
                      children: [
                        MatchConstants.buildTeamLogo(
                          match?['localLogo'] ?? '⚽',
                          match?['localEmoji'] ?? '⚽',
                          48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          match?['local'] ?? prediction['homeTeam'] ?? 'Equipo',
                          style: TextStyle(
                            color: isClosed
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Marcador (Predicción del usuario)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isCorrect && hasRealResult
                          ? Colors.green.withValues(alpha: 0.3)
                          : AppColors.primaryPurple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCorrect && hasRealResult
                            ? Colors.greenAccent.withValues(alpha: 0.5)
                            : AppColors.primaryPurple.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${prediction['homeScore'] ?? 0} - ${prediction['awayScore'] ?? 0}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (hasRealResult)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Real: $realScoreText',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 9,
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
                          match?['visitorLogo'] ?? '⚽',
                          match?['visitorEmoji'] ?? '⚽',
                          48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          match?['visitor'] ?? prediction['awayTeam'] ?? 'Equipo',
                          style: TextStyle(
                            color: isClosed
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ✅ Indicador de acierto/error
              if (hasRealResult)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCorrect ? Icons.check_circle : Icons.cancel,
                          size: 14,
                          color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isCorrect ? '¡Acertaste!' : 'No acertaste',
                          style: TextStyle(
                            color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
  bool _isPredictionCorrect(Map<String, dynamic> prediction, Map<String, dynamic> match) {
    final userHome = prediction['homeScore'] as int?;
    final userAway = prediction['awayScore'] as int?;
    final realHome = match['realHomeScore'] as int?;
    final realAway = match['realAwayScore'] as int?;

    // Solo comparar si ambos resultados existen
    if (userHome != null && userAway != null && realHome != null && realAway != null) {
      return userHome == realHome && userAway == realAway;
    }
    return false;
  }
}
