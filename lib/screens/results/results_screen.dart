import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/bet_status.dart';
import '../../core/constants/matches_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/team_name_utils.dart';
import '../../models/bet_model.dart';
import '../../models/polla_model.dart';
import '../../models/user_model.dart';
import '../../services/admin_bet_service.dart';
import '../../services/match_service.dart';
import '../../services/polla_service.dart';
import '../../services/user_service.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final PollaService _pollaService = PollaService();
  final MatchService _matchService = MatchService();
  final AdminBetService _adminBetService = AdminBetService();
  final UserService _userService = UserService();

  List<PollaModel> _jornadas = [];
  PollaModel? _selectedJornada;
  List<Map<String, dynamic>> _matches = [];
  List<BetModel> _bets = [];
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
      _jornadas = await _pollaService.getAvailableJornadas();

      if (_jornadas.isNotEmpty) {
        _selectedJornada = _jornadas.first;
        await _loadJornadaData(_selectedJornada!.id);
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

  Future<void> _loadJornadaData(String pollaId) async {
    setState(() => _isLoading = true);

    try {
      final matchesData = await _matchService.getMatchesForBetScreen(pollaId);
      _matches = matchesData;
      if (matchesData.isNotEmpty) {
        MatchConstants.setMatches(matchesData, pollaId: pollaId);
      }

      final bets = await _adminBetService.getBetsByJornada(pollaId);
      _bets = bets..sort((a, b) {
        if (a.status == BetStatus.winner && b.status != BetStatus.winner) return -1;
        if (a.status != BetStatus.winner && b.status == BetStatus.winner) return 1;
        return b.exactHits.compareTo(a.exactHits);
      });

      await _loadUsersInfo();

      setState(() => _isLoading = false);
    } on FirebaseException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error de permisos: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar datos: $e';
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
    if (_selectedJornada?.id == jornada.id) return;
    setState(() => _selectedJornada = jornada);
    await _loadJornadaData(jornada.id);
  }

  int _calcExactHits(BetModel bet) {
    int hits = 0;
    for (int i = 0; i < bet.predictions.length; i++) {
      final pred = bet.predictions[i];
      final match = MatchConstants.getMatchByIndex(i, pollaId: bet.pollaId);
      if (match['realHomeScore'] != null && match['realAwayScore'] != null &&
          pred['homeScore'] == match['realHomeScore'] &&
          pred['awayScore'] == match['realAwayScore']) {
        hits++;
      }
    }
    return hits;
  }

  int _totalFinished() {
    int count = 0;
    for (final m in _matches) {
      if (m['realHomeScore'] != null && m['realAwayScore'] != null) {
        count++;
      }
    }
    return count;
  }

  List<BetModel> _getWinners() {
    if (_bets.isEmpty) return [];
    final total = _totalFinished();
    if (total == 0) return [];

    final winners = _bets.where((b) {
      final userHits = _calcExactHits(b);
      return userHits == total;
    }).toList();

    if (winners.isEmpty) {
      _bets.sort((a, b) => _calcExactHits(b).compareTo(_calcExactHits(a)));
      final topHits = _calcExactHits(winners.isNotEmpty ? winners.first : _bets.first);
      return _bets.where((b) => _calcExactHits(b) == topHits).toList();
    }

    return winners;
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('PARTIDOS'),
                  const SizedBox(height: 8),
                  _buildMatchResults(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('GANADORES'),
                  const SizedBox(height: 8),
                  _buildWinnersSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
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

  Widget _buildMatchResults() {
    if (_matches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text(
            'No hay partidos disponibles',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return Column(
      children: _matches.asMap().entries.map((entry) {
        final index = entry.key;
        final match = entry.value;
        final hasResult = match['realHomeScore'] != null && match['realAwayScore'] != null;
        final scoreText = hasResult
            ? '${match['realHomeScore']} - ${match['realAwayScore']}'
            : 'VS';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasResult
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    MatchConstants.buildTeamLogo(
                      match['localLogo'] ?? '',
                      match['localEmoji'] ?? '',
                      32,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      TeamNameUtils.getShortName(match['local'] ?? ''),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: hasResult
                      ? Colors.green.withValues(alpha: 0.15)
                      : AppColors.primaryPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasResult
                        ? Colors.greenAccent.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      scoreText,
                      style: TextStyle(
                        color: hasResult ? Colors.greenAccent : Colors.white54,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (hasResult)
                      Text(
                        'FT',
                        style: TextStyle(
                          color: Colors.greenAccent.withValues(alpha: 0.6),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    MatchConstants.buildTeamLogo(
                      match['visitorLogo'] ?? '',
                      match['visitorEmoji'] ?? '',
                      32,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      TeamNameUtils.getShortName(match['visitor'] ?? ''),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWinnersSection() {
    if (_bets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text(
            'No hay apuestas registradas',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final total = _totalFinished();

    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            'Esperando resultados...',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          ),
        ),
      );
    }

    final topBets = List<BetModel>.from(_bets)..sort((a, b) => _calcExactHits(b).compareTo(_calcExactHits(a)));
    final topHits = topBets.isNotEmpty ? _calcExactHits(topBets.first) : 0;
    final leaders = topBets.where((b) => _calcExactHits(b) == topHits).toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryPurple.withValues(alpha: 0.2),
                AppColors.energeticRed.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: topHits == total && total > 0
                  ? Colors.greenAccent.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Partidos finalizados: $total / ${_matches.length}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
              Text(
                'Mejor puntaje: $topHits aciertos',
                style: TextStyle(
                  color: topHits == total && total > 0
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...leaders.map((bet) => _buildLeaderCard(bet)),
      ],
    );
  }

  Widget _buildLeaderCard(BetModel bet) {
    final user = _usersCache[bet.uid];
    final userName = user?.name ?? 'Usuario ${bet.uid.substring(0, 6)}';
    final userAvatar = user?.avatar ?? '';
    final userHits = _calcExactHits(bet);
    final total = _totalFinished();
    final isPerfect = userHits == total && total > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: isPerfect ? 0.08 : 0.04),
            Colors.white.withValues(alpha: isPerfect ? 0.03 : 0.01),
          ],
        ),
        border: Border.all(
          color: isPerfect
              ? Colors.greenAccent.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isPerfect
                      ? [Colors.greenAccent, Colors.green]
                      : [AppColors.primaryPurple, AppColors.energeticRed],
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
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Aciertos: $userHits / $total',
                    style: TextStyle(
                      color: isPerfect ? Colors.greenAccent : Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (isPerfect)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.greenAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'GANADOR',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
