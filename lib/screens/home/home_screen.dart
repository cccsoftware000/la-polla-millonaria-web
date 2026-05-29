import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/bet_status.dart';
import '../../core/constants/matches_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/bet_status_helper.dart';
import '../../core/utils/team_name_utils.dart';
import '../../models/polla_model.dart';
import '../../models/user_model.dart';
import '../../services/accumulated_service.dart';
import '../../services/analytics_service.dart';
import '../../services/cache_service.dart';
import '../../services/match_service.dart';
import '../../services/polla_service.dart';
import '../../services/user_service.dart';
import '../../services/bet_service.dart';
import '../../models/bet_model.dart';
import '../../widgets/animated_accumulated_card.dart';
import '../../widgets/predictions_carousel.dart';
import '../bet/bet_detail_screen.dart';
import '../bet/bet_screen.dart';
import '../profile/profile_screen.dart';
import '../ranking/ranking_screen.dart';
import '../results/results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final UserService userService = UserService();
  final BetService betService = BetService();
  final MatchService _matchService = MatchService();
  final PollaService _pollaService = PollaService();
  StreamSubscription? _betsSubscription;
  bool _isFirstLoad = true;
  bool _isLoadingMatches = true;
  UserModel? user;
  List<BetModel> bets = [];
  bool isLoading = true;
  late AnimationController glowController;
  late AnimationController breathingController;
  Timer? _refreshTimer;
  List<PollaModel> _jornadas = [];
  PollaModel? _selectedJornada;
  bool _isLoadingJornadas = true;
  bool _isRefreshingJornadas = false;

  @override
  void initState() {
    super.initState();
    _loadDataOnce();
    AnalyticsService.logScreen(screenName: 'home_screen');

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    loadUser();
    _loadMatchesForActivePolla();

    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _refreshData();
    });
  }

  Future<void> _loadDataOnce() async {
    if (!_isFirstLoad) return;
    _isFirstLoad = false;

    final cachedUserMap = await CacheService.getCachedUser();
    if (cachedUserMap != null) {
      final userModel = UserModel.fromMap(cachedUserMap);
      setState(() => user = userModel);
    }
    await loadUser();
  }

  Future<void> loadUser() async {
    final currentUser = await userService.getCurrentUser();
    final jornadas = await _pollaService.getAvailableJornadas();
    final allBets = await betService.getUserBets();

    if (mounted) {
      setState(() {
        user = currentUser;
        bets = allBets;
        _jornadas = jornadas;
        _selectedJornada = null;
        isLoading = false;
        _isLoadingJornadas = false;
      });
    }
  }

  Future<void> _filterBetsByJornada(PollaModel? jornada) async {
    if (user == null) return;

    setState(() {
      _selectedJornada = jornada;
      _isRefreshingJornadas = true;
    });

    try {
      List<BetModel> filteredBets;
      if (jornada == null) {
        filteredBets = await betService.getUserBets();
      } else {
        filteredBets = await _pollaService.getBetsByPolla(user!.uid, jornada.id);
      }

      if (mounted) {
        setState(() {
          bets = filteredBets;
          _isRefreshingJornadas = false;
        });
      }
    } catch (e) {
      print('Error filtering bets: $e');
      if (mounted) {
        setState(() => _isRefreshingJornadas = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar apuestas: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildJornadaSelector() {
    if (_jornadas.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.filter_list, size: 14, color: Colors.white.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text(
                'FILTRAR POR JORNADA',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _jornadas.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = _selectedJornada == null;
                return GestureDetector(
                  onTap: () => _filterBetsByJornada(null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: isSelected
                          ? const LinearGradient(
                        colors: [AppColors.primaryPurple, AppColors.energeticRed],
                      )
                          : null,
                      color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Todas',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }
              final jornada = _jornadas[index - 1];
              final isSelected = _selectedJornada?.id == jornada.id;
              final isClosed = jornada.status != 'ACTIVE' || jornada.closedAt != null;

              return GestureDetector(
                onTap: () => _filterBetsByJornada(jornada),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: isSelected
                        ? const LinearGradient(
                      colors: [AppColors.primaryPurple, AppColors.energeticRed],
                    )
                        : null,
                    color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isClosed && !isSelected)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.lock_outline,
                            size: 10,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      Text(
                        jornada.name.length > 20 ? '${jornada.name.substring(0, 18)}...' : jornada.name,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : isClosed
                              ? Colors.white.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.6),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_isRefreshingJornadas)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryPurple,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _refreshData() async {
    final currentUser = await userService.getCurrentUser();
    final jornadas = await _pollaService.getAvailableJornadas();

    if (_selectedJornada != null && currentUser != null) {
      final filteredBets = await _pollaService.getBetsByPolla(
        currentUser.uid,
        _selectedJornada!.id,
      );
      if (mounted) {
        setState(() {
          user = currentUser;
          bets = filteredBets;
          _jornadas = jornadas;
        });
      }
    } else if (mounted) {
      final allBets = await betService.getUserBets();
      setState(() {
        user = currentUser;
        bets = allBets;
        _jornadas = jornadas;
      });
    }
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  int getPendingBetsCount() {
    return bets.where((bet) => bet.status == BetStatus.pendingPayment).length;
  }

  int getActiveBetsCount() {
    return bets.where((bet) => bet.status == BetStatus.active).length;
  }

  @override
  void dispose() {
    glowController.dispose();
    breathingController.dispose();
    _refreshTimer?.cancel();
    _betsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.primaryPurple,
        backgroundColor: Colors.black,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A0A1A), Color(0xFF1A0A2E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              _buildBackgroundGlows(),
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildQuickActions(),
                      const SizedBox(height: 24),
                      _buildStatsRow(),
                      const SizedBox(height: 24),
                      _buildPrizeCard(),
                      const SizedBox(height: 28),
                      _buildSectionTitle('🎯 POLLAS DISPONIBLES', Icons.sports_soccer),
                      const SizedBox(height: 16),
                      _buildAvailableBetsCard(),
                      const SizedBox(height: 28),
                      _buildSectionTitle('📋 MIS APUESTAS', Icons.history),
                      const SizedBox(height: 16),
                      _buildBetsHistory(),
                      const SizedBox(height: 24),
                      _buildFooterText(),
                      const SizedBox(height: 16),
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

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: AppColors.primaryPurple),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickAction(
            icon: Icons.emoji_events,
            label: 'Resultados',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ResultsScreen()),
              );
            },
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickAction(
            icon: Icons.leaderboard,
            label: 'Ranking',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RankingScreen()),
              );
            },
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickAction(
            icon: Icons.person,
            label: 'Perfil',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ).then((_) => _refreshData());
            },
            color: AppColors.primaryPurple,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              tween: Tween(begin: 0.8, end: 1.2),
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              builder: (_, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryPurple, AppColors.energeticRed],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPurple.withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('⚽', style: TextStyle(fontSize: 40)),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Cargando experiencia premium...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              color: AppColors.primaryPurple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -50,
          child: AnimatedBuilder(
            animation: glowController,
            builder: (context, _) => Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryPurple.withValues(alpha: 0.1 + (glowController.value * 0.05)),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -80,
          right: -80,
          child: AnimatedBuilder(
            animation: glowController,
            builder: (context, _) => Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.energeticRed.withValues(alpha: 0.08 + (glowController.value * 0.04)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                getGreeting(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.name ?? 'Fanático',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Nivel ${user?.level} · ${user?.levelTitle}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Avatar
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ).then((_) => _refreshData());
          },
          child: Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primaryPurple, AppColors.energeticRed],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPurple.withValues(alpha: 0.3),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Center(
              child: Text(
                user?.avatar ?? '👤',
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    final pendingCount = getPendingBetsCount();
    final activeCount = getActiveBetsCount();
    final totalMatches = MatchConstants.getMatchCount();

    return Row(
      children: [
        _buildStatCard(
          icon: Icons.pending_actions,
          value: '$pendingCount',
          label: 'Pendientes',
          color: Colors.orange,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          icon: Icons.play_circle_outline,
          value: '$activeCount',
          label: 'Activas',
          color: Colors.green,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          icon: Icons.sports_soccer,
          value: '$totalMatches',
          label: 'Partidos',
          color: AppColors.primaryPurple,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrizeCard() {
    return AnimatedAccumulatedCard(
      accumulatedStream: AccumulatedService().streamAccumulated(),
    );
  }

  Widget _buildAvailableBetsCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BetScreen()),
        ).then((_) => _refreshData());
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.06),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryPurple, AppColors.energeticRed],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('🏆', style: TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jornada Activa',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedJornada?.name ?? 'La Polla Millonaria',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${MatchConstants.getMatchCount()} partidos disponibles',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBetsHistory() {
    return Column(
      children: [
        _buildJornadaSelector(),
        const SizedBox(height: 16),
        if (_isRefreshingJornadas)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            ),
          )
        else if (bets.isEmpty)
          _buildEmptyState()
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: bets.length,
            itemBuilder: (context, index) {
              return _buildBetCard(bets[index]);
            },
          ),
      ],
    );
  }

  Widget _buildBetCard(BetModel bet) {
    String statusText = BetStatusHelper.getText(bet.status);
    Color statusColor = BetStatusHelper.getColor(bet.status);
    IconData statusIcon = BetStatusHelper.getIcon(bet.status);

    // ✅ Calcular aciertos de la apuesta
    int totalCorrect = 0;
    int totalFinished = 0;

    for (int i = 0; i < bet.predictions.length; i++) {
      final prediction = bet.predictions[i];
      final match = MatchConstants.getMatchByIndex(i);

      final hasRealResult = match['realHomeScore'] != null && match['realAwayScore'] != null;
      if (hasRealResult) {
        totalFinished++;
        final userHome = prediction['homeScore'] as int?;
        final userAway = prediction['awayScore'] as int?;
        final realHome = match['realHomeScore'] as int?;
        final realAway = match['realAwayScore'] as int?;

        if (userHome == realHome && userAway == realAway) {
          totalCorrect++;
        }
      }
    }

    final accuracy = totalFinished > 0 ? (totalCorrect / totalFinished * 100).round() : 0;
    final isWinner = bet.status == BetStatus.winner;

    // Mostrar primeros 3 partidos con detalles completos
    final displayedPredictions = bet.predictions.take(3).toList();
    final remainingCount = bet.predictions.length - 3;

    // Obtener primeros 6 caracteres del ID
    final shortId = bet.id.length > 6 ? bet.id.substring(0, 6).toUpperCase() : bet.id.toUpperCase();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BetDetailScreen(bet: bet),
          ),
        ).then((_) => _refreshData());
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con estado, ID, fecha y resultados
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
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
                  const SizedBox(width: 8),
                  // ID corto
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#$shortId',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 9,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const Spacer(),
                  // ✅ Badge de aciertos (solo si hay partidos finalizados)
                  if (totalFinished > 0 && !isWinner)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: totalCorrect == totalFinished
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        totalCorrect == totalFinished
                            ? '✅ $accuracy%'
                            : '🎯 $accuracy%',
                        style: TextStyle(
                          color: totalCorrect == totalFinished
                              ? Colors.greenAccent
                              : Colors.orangeAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  // Badge de cantidad de partidos
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${bet.predictions.length}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 9,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Fecha
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 10, color: Colors.white.withValues(alpha: 0.4)),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateShort(bet.createdAt?.toDate()),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Lista horizontal de partidos (sin cambios)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: displayedPredictions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final prediction = entry.value;
                    final match = MatchConstants.getMatchByIndex(index);
                    final isLast = index == displayedPredictions.length - 1;

                    // ✅ Verificar si el usuario acertó este partido
                    final hasRealResult = match?['realHomeScore'] != null && match?['realAwayScore'] != null;
                    final isCorrect = hasRealResult &&
                        prediction['homeScore'] == match?['realHomeScore'] &&
                        prediction['awayScore'] == match?['realAwayScore'];

                    // Obtener nombres cortos usando el nuevo utilitario
                    final localShort = TeamNameUtils.getShortName(match?['local'] ?? '');
                    final visitorShort = TeamNameUtils.getShortName(match?['visitor'] ?? '');

                    return Row(
                      children: [
                        // Tarjeta de partido con indicador de acierto
                        Container(
                          width: 110,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? Colors.green.withValues(alpha: 0.1)
                                : (hasRealResult && !isCorrect
                                ? Colors.red.withValues(alpha: 0.05)
                                : Colors.white.withValues(alpha: 0.04)),
                            borderRadius: BorderRadius.circular(14),
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
                              // Logos y marcador
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  MatchConstants.buildTeamLogo(
                                    match?['localLogo'] ?? '⚽',
                                    match?['localEmoji'] ?? '⚽',
                                    22,
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isCorrect
                                          ? Colors.green.withValues(alpha: 0.3)
                                          : (hasRealResult && !isCorrect
                                          ? Colors.red.withValues(alpha: 0.3)
                                          : AppColors.primaryPurple.withValues(alpha: 0.2)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${prediction['homeScore']} - ${prediction['awayScore']}',
                                      style: TextStyle(
                                        color: isCorrect
                                            ? Colors.greenAccent
                                            : (hasRealResult && !isCorrect
                                            ? Colors.redAccent
                                            : Colors.white),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  MatchConstants.buildTeamLogo(
                                    match?['visitorLogo'] ?? '⚽',
                                    match?['visitorEmoji'] ?? '⚽',
                                    22,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Nombres de equipos (abreviados)
                              Text(
                                localShort,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'vs',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 7,
                                ),
                              ),
                              Text(
                                visitorShort,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              // ✅ Mini check si acertó
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
                        // Separador entre partidos
                        if (!isLast)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.2),
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
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '+$remainingCount partidos más',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ✅ Resumen de aciertos
              if (totalFinished > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Aciertos: $totalCorrect / $totalFinished',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                      if (totalCorrect == totalFinished && totalFinished > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'PLENO',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              // Badge de ganador
              if (isWinner)
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events, color: Colors.greenAccent, size: 14),
                        SizedBox(width: 4),
                        Text(
                          '+ \$500.000',
                          style: TextStyle(
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

// Método auxiliar para fecha corta
  String _formatDateShort(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Ahora';
    }
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          TweenAnimationBuilder(
            tween: Tween(begin: 0.9, end: 1.1),
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            builder: (_, value, child) {
              return Transform.scale(
                scale: value,
                child: const Text('🎟️', style: TextStyle(fontSize: 48)),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Aún no tienes apuestas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Realiza tu primera apuesta y gana millones',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BetScreen()),
              ).then((_) => _refreshData());
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryPurple, width: 1.5),
              ),
              child: Text(
                'COMENZAR AHORA',
                style: TextStyle(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterText() {
    return Center(
      child: Column(
        children: [
          const Text(
            '⚡ La pasión también se juega ⚽',
            style: TextStyle(
              color: Colors.white30,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 50,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, AppColors.primaryPurple, Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }
  // lib/screens/home/home_screen.dart

  Future<void> _loadMatchesForActivePolla() async {
    try {
      // ✅ Intentar cargar la polla activa primero
      PollaModel? polla = await _pollaService.getActivePolla();

      // ✅ Si no hay activa, buscar la última jornada (aunque esté cerrada)
      if (polla == null) {
        final allPollas = await _pollaService.getAllPollas();
        if (allPollas.isNotEmpty) {
          // Tomar la más reciente por fecha
          polla = allPollas.first;
          print('📊 No hay polla activa, usando última: ${polla.name} (${polla.status})');
        }
      }

      if (polla != null) {
        final matches = await _matchService.getMatchesForBetScreen(polla.id);
        if (matches.isNotEmpty) {
          MatchConstants.setMatches(matches, pollaId: polla.id);
          print('✅ Cargados ${matches.length} partidos para ${polla.name}');
        }
      } else {
        print('⚠️ No se encontró ninguna polla');
      }
    } catch (e) {
      print('Error loading matches: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMatches = false;
        });
      }
    }
  }
}