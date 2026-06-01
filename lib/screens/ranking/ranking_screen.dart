// lib/screens/ranking/ranking_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/bet_status.dart';
import '../../core/constants/matches_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/team_name_utils.dart';
import '../../models/bet_model.dart';
import '../../models/polla_model.dart';
import '../../models/user_model.dart';
import '../../services/admin_bet_service.dart';
import '../../services/polla_service.dart';
import '../../services/user_service.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final AdminBetService _adminBetService = AdminBetService();
  final PollaService _pollaService = PollaService();
  final UserService _userService = UserService();

  List<BetModel> _bets = [];
  List<PollaModel> _jornadas = [];
  PollaModel? _selectedJornada;
  Map<String, UserModel> _usersCache = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Cargar jornadas disponibles
      _jornadas = await _pollaService.getAvailableJornadas();

      if (_jornadas.isNotEmpty) {
        _selectedJornada = _jornadas.first;
        await _loadBetsByJornada(_selectedJornada!.id);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No hay jornadas disponibles';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar datos: $e';
      });
    }
  }

  Future<void> _loadBetsByJornada(String pollaId) async {
    setState(() => _isLoading = true);

    try {
      final bets = await _adminBetService.getBetsByJornada(pollaId);

      if (bets.isEmpty) {
        print('⚠️ No se encontraron apuestas para la jornada $pollaId');
      }

      _bets = bets..sort((a, b) {
        if (a.status == BetStatus.winner && b.status != BetStatus.winner) return -1;
        if (a.status != BetStatus.winner && b.status == BetStatus.winner) return 1;
        return b.exactHits.compareTo(a.exactHits);
      });

      await _loadUsersInfo();

      setState(() => _isLoading = false);
    } on FirebaseException catch (e) {
      print('❌ Firebase error: ${e.code} - ${e.message}');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error de permisos: ${e.message}';
      });
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar apuestas: $e';
      });
    }
  }

  Future<void> _loadUsersInfo() async {
    final uids = _bets.map((b) => b.uid).toSet().toList();

    for (final uid in uids) {
      if (!_usersCache.containsKey(uid)) {
        final user = await _userService.getUserById(uid);
        if (user != null) {
          _usersCache[uid] = user;
        }
      }
    }
  }

  Future<void> _onJornadaSelected(PollaModel jornada) async {
    setState(() {
      _selectedJornada = jornada;
    });
    await _loadBetsByJornada(jornada.id);
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
          'APUESTAS GLOBALES',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
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
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
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
          _buildJornadaSelector(),
          const SizedBox(height: 16),
          Expanded(
            child: _bets.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('📭', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text(
                    'No hay apuestas en esta jornada',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _bets.length,
              itemBuilder: (context, index) {
                return _buildBetCard(_bets[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJornadaSelector() {
    if (_jornadas.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _jornadas.length,
        itemBuilder: (context, index) {
          final jornada = _jornadas[index];
          final isSelected = _selectedJornada?.id == jornada.id;

          return GestureDetector(
            onTap: () => _onJornadaSelected(jornada),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
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
                  jornada.name,
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

  // lib/screens/ranking/ranking_screen.dart

// Reemplaza el método _buildBetCard con esta versión

  Widget _buildBetCard(BetModel bet) {
    final user = _usersCache[bet.uid];
    final userName = user?.name ?? 'Usuario ${bet.uid.substring(0, 6)}';
    final userAvatar = user?.avatar ?? '👤';
    final isWinner = bet.status == BetStatus.winner;
    final isActive = bet.status == BetStatus.active;

    // ✅ CALCULAR ACIERTOS EN TIEMPO REAL
    int realExactHits = 0;
    int totalFinished = 0;

    for (int i = 0; i < bet.predictions.length; i++) {
      final prediction = bet.predictions[i];
      final match = MatchConstants.getMatchByIndex(i, pollaId: bet.pollaId);

      if (match['realHomeScore'] != null && match['realAwayScore'] != null) {
        totalFinished++;
        if (prediction['homeScore'] == match['realHomeScore'] &&
            prediction['awayScore'] == match['realAwayScore']) {
          realExactHits++;
        }
      }
    }

    // Mostrar TODOS los partidos (no solo 3)
    final allPredictions = bet.predictions;
    final remainingCount = 0; // Ya no hay restantes porque mostramos todos

    return Container(
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
          color: isWinner
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: usuario y estado
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primaryPurple, AppColors.energeticRed],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      userAvatar,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ID: ${bet.uid.substring(0, 8)}...',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isWinner
                        ? Colors.greenAccent.withValues(alpha: 0.2)
                        : (isActive
                        ? Colors.orange.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isWinner
                        ? 'GANADOR'
                        : (isActive
                        ? 'EN CURSO'
                        : 'FINALIZADA'),
                    style: TextStyle(
                      color: isWinner
                          ? Colors.greenAccent
                          : (isActive
                          ? Colors.orange
                          : Colors.white.withValues(alpha: 0.5)),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ✅ MOSTRAR TODOS LOS 8 PARTIDOS (en scroll horizontal)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: allPredictions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final prediction = entry.value;
                  final match = MatchConstants.getMatchByIndex(index, pollaId: bet.pollaId);
                  final isLast = index == allPredictions.length - 1;

                  final hasRealResult = match['realHomeScore'] != null && match['realAwayScore'] != null;
                  final isCorrect = hasRealResult &&
                      prediction['homeScore'] == match['realHomeScore'] &&
                      prediction['awayScore'] == match['realAwayScore'];

                  return Row(
                    children: [
                      Container(
                        width: 110,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? Colors.green.withValues(alpha: 0.1)
                              : (hasRealResult && !isCorrect
                              ? Colors.red.withValues(alpha: 0.05)
                              : Colors.white.withValues(alpha: 0.03)),
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
                                  match['localLogo'] ?? '⚽',
                                  match['localEmoji'] ?? '⚽',
                                  22,
                                ),
                                const SizedBox(width: 4),
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
                                    '${prediction['homeScore']}-${prediction['awayScore']}',
                                    style: TextStyle(
                                      color: isCorrect
                                          ? Colors.greenAccent
                                          : (hasRealResult && !isCorrect
                                          ? Colors.redAccent
                                          : Colors.white),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                MatchConstants.buildTeamLogo(
                                  match['visitorLogo'] ?? '⚽',
                                  match['visitorEmoji'] ?? '⚽',
                                  22,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Nombres abreviados
                            Text(
                              TeamNameUtils.getShortName(match['local'] ?? ''),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 9,
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
                              TeamNameUtils.getShortName(match['visitor'] ?? ''),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 9,
                              ),
                            ),
                            // Resultado real
                            if (hasRealResult)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${match['realHomeScore']}-${match['realAwayScore']}',
                                  style: TextStyle(
                                    color: isCorrect
                                        ? Colors.greenAccent
                                        : (hasRealResult && !isCorrect
                                        ? Colors.redAccent
                                        : Colors.white.withValues(alpha: 0.4)),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            // Mini check
                            if (hasRealResult)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  isCorrect ? Icons.check_circle : Icons.cancel,
                                  size: 12,
                                  color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),

            // Resumen de aciertos
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: realExactHits == totalFinished && totalFinished > 0
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '✅ Aciertos: $realExactHits / $totalFinished',
                    style: TextStyle(
                      color: realExactHits == totalFinished && totalFinished > 0
                          ? Colors.greenAccent
                          : Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (isWinner && bet.prize != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.greenAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '+ \$${bet.prize!.toInt().toString()}',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}