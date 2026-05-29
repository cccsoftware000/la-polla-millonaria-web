// lib/screens/profile/stats_screen.dart
import 'package:flutter/material.dart';
import '../../core/constants/bet_status.dart';
import '../../core/theme/app_colors.dart';
import '../../models/bet_model.dart';
import '../../services/bet_service.dart';
import '../../services/polla_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with TickerProviderStateMixin {
  final BetService _betService = BetService();
  final PollaService _pollaService = PollaService();

  List<BetModel> _allBets = [];
  bool _isLoading = true;
  late AnimationController _progressController;

  // Estadísticas
  int _totalBets = 0;
  int _pendingBets = 0;
  int _activeBets = 0;
  int _wonBets = 0;
  int _completedBets = 0;
  int _totalExactHits = 0;
  int _bestJornadaHits = 0;
  String _bestJornadaName = '';
  double _avgHitsPerBet = 0;

  // Datos para gráfico de barras
  Map<String, int> _hitsPerJornada = {};

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..forward();
    _loadStats();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    _allBets = await _betService.getUserBets();
    final jornadas = await _pollaService.getAllPollas();

    // Calcular estadísticas
    _totalBets = _allBets.length;
    _pendingBets = _allBets.where((b) => b.status == BetStatus.pendingPayment).length;
    _activeBets = _allBets.where((b) => b.status == BetStatus.active).length;
    _wonBets = _allBets.where((b) => b.status == BetStatus.winner).length;
    _completedBets = _allBets.where((b) => b.status == BetStatus.completed).length;
    _totalExactHits = _allBets.fold(0, (sum, bet) => sum + bet.exactHits);
    _avgHitsPerBet = _totalBets > 0 ? _totalExactHits / _totalBets : 0;

    // Encontrar mejor jornada
    for (var bet in _allBets) {
      final jornada = jornadas.firstWhere(
            (j) => j.id == bet.pollaId,
        orElse: () => throw Exception('Jornada no encontrada'),
      );
      _hitsPerJornada[jornada.name] = (_hitsPerJornada[jornada.name] ?? 0) + bet.exactHits;
    }

    if (_hitsPerJornada.isNotEmpty) {
      _bestJornadaName = _hitsPerJornada.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      _bestJornadaHits = _hitsPerJornada[_bestJornadaName] ?? 0;
    }

    setState(() => _isLoading = false);
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
          'Mis Estadísticas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Tarjeta de resumen
            _buildSummaryCard(),
            const SizedBox(height: 20),

            // Grid de stats
            _buildStatsGrid(),
            const SizedBox(height: 20),

            // Mejor jornada
            _buildBestJornadaCard(),
            const SizedBox(height: 20),

            // Gráfico de aciertos por jornada
            _buildHitsChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColors.primaryPurple, AppColors.energeticRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const Text(
            'EFECTIVIDAD GENERAL',
            style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: _totalBets > 0 ? (_wonBets / _totalBets) * 100 : 0),
            duration: const Duration(seconds: 1),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Text(
                '${value.toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${_wonBets} de $_totalBets apuestas ganadas',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      {'icon': Icons.sports_soccer, 'value': '$_totalBets', 'label': 'Apuestas', 'color': Colors.blue},
      {'icon': Icons.pending_actions, 'value': '$_pendingBets', 'label': 'Pendientes', 'color': Colors.orange},
      {'icon': Icons.play_circle_outline, 'value': '$_activeBets', 'label': 'Activas', 'color': Colors.green},
      {'icon': Icons.emoji_events, 'value': '$_wonBets', 'label': 'Ganadas', 'color': Colors.amber},
      {'icon': Icons.check_circle_outline, 'value': '$_completedBets', 'label': 'Finalizadas', 'color': Colors.grey},
      {'icon': Icons.trending_up, 'value': '${_avgHitsPerBet.toStringAsFixed(1)}', 'label': 'Promedio aciertos', 'color': AppColors.primaryPurple},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(stat['icon'] as IconData, color: stat['color'] as Color, size: 28),
              const SizedBox(height: 8),
              Text(
                stat['value'] as String,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                stat['label'] as String,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBestJornadaCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Center(
              child: Icon(Icons.emoji_events, color: Colors.amber, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🏆 Mejor Jornada',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _bestJornadaName.isNotEmpty ? _bestJornadaName : 'Sin datos',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_bestJornadaHits aciertos totales',
                  style: TextStyle(color: Colors.amber, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHitsChart() {
    if (_hitsPerJornada.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxHits = _hitsPerJornada.values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACIERTOS POR JORNADA',
            style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5),
          ),
          const SizedBox(height: 20),
          ..._hitsPerJornada.entries.map((entry) {
            // ✅ Calcular porcentaje de forma segura
            final double percentage = maxHits > 0 ? entry.value / maxHits : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key.length > 25 ? '${entry.key.substring(0, 25)}...' : entry.key,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.value}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: percentage.clamp(0.0, 1.0), // ✅ Asegurar que esté entre 0 y 1
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}