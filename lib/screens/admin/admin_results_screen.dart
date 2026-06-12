import 'package:flutter/material.dart';
import '../../core/constants/matches_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/team_name_utils.dart';
import '../../models/polla_model.dart';
import '../../services/match_service.dart';
import '../../services/polla_service.dart';

class AdminResultsScreen extends StatefulWidget {
  const AdminResultsScreen({super.key});

  @override
  State<AdminResultsScreen> createState() => _AdminResultsScreenState();
}

class _AdminResultsScreenState extends State<AdminResultsScreen> {
  final PollaService _pollaService = PollaService();
  final MatchService _matchService = MatchService();

  List<PollaModel> _jornadas = [];
  PollaModel? _selectedJornada;
  List<Map<String, dynamic>> _matches = [];
  late List<TextEditingController> _homeControllers;
  late List<TextEditingController> _awayControllers;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _homeControllers = [];
    _awayControllers = [];
    _loadJornadas();
  }

  Future<void> _loadJornadas() async {
    setState(() => _isLoading = true);
    try {
      _jornadas = await _pollaService.getAvailableJornadas();
      if (_jornadas.isNotEmpty) {
        _selectedJornada = _jornadas.first;
        await _loadMatches(_selectedJornada!.id);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMatches(String pollaId) async {
    setState(() => _isLoading = true);
    try {
      final matches = await _matchService.getMatchesForBetScreen(pollaId);
      _matches = matches;
      MatchConstants.setMatches(matches, pollaId: pollaId);
      _initControllers();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _initControllers() {
    for (var c in _homeControllers) { c.dispose(); }
    for (var c in _awayControllers) { c.dispose(); }

    _homeControllers = List.generate(_matches.length, (i) {
      final existing = _matches[i]['realHomeScore'];
      return TextEditingController(text: existing?.toString() ?? '');
    });
    _awayControllers = List.generate(_matches.length, (i) {
      final existing = _matches[i]['realAwayScore'];
      return TextEditingController(text: existing?.toString() ?? '');
    });
  }

  Future<void> _saveResults() async {
    List<Map<String, dynamic>> updates = [];

    for (int i = 0; i < _matches.length; i++) {
      final homeText = _homeControllers[i].text.trim();
      final awayText = _awayControllers[i].text.trim();

      if (homeText.isEmpty && awayText.isEmpty) continue;

      final homeScore = int.tryParse(homeText);
      final awayScore = int.tryParse(awayText);

      if (homeScore == null || awayScore == null) {
        _showError('Marcador inválido en ${_matches[i]['local']} vs ${_matches[i]['visitor']}');
        return;
      }

      updates.add({
        'matchId': _matches[i]['id'],
        'homeScore': homeScore,
        'awayScore': awayScore,
      });
    }

    if (updates.isEmpty) {
      _showError('No hay marcadores para guardar');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _matchService.updateMatchScoresBatch(updates);

      for (final u in updates) {
        final idx = _matches.indexWhere((m) => m['id'] == u['matchId']);
        if (idx >= 0) {
          _matches[idx]['realHomeScore'] = u['homeScore'];
          _matches[idx]['realAwayScore'] = u['awayScore'];
        }
      }

      if (_selectedJornada != null) {
        MatchConstants.setMatches(_matches, pollaId: _selectedJornada!.id);
      }

      setState(() => _isSaving = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${updates.length} resultado${updates.length > 1 ? 's' : ''} guardado${updates.length > 1 ? 's' : ''}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Error al guardar: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    for (var c in _homeControllers) { c.dispose(); }
    for (var c in _awayControllers) { c.dispose(); }
    super.dispose();
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
          'ADMIN RESULTADOS',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
          : _jornadas.isEmpty
          ? const Center(child: Text('No hay jornadas disponibles', style: TextStyle(color: Colors.white54)))
          : Column(
              children: [
                _buildJornadaSelector(),
                const SizedBox(height: 16),
                Expanded(child: _buildMatchList()),
                _buildSaveButton(),
              ],
            ),
    );
  }

  Widget _buildJornadaSelector() {
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
            onTap: () {
              if (_selectedJornada?.id != jornada.id) {
                setState(() => _selectedJornada = jornada);
                _loadMatches(jornada.id);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: isSelected
                    ? const LinearGradient(colors: [AppColors.primaryPurple, AppColors.energeticRed])
                    : null,
                color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.08),
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

  Widget _buildMatchList() {
    if (_matches.isEmpty) {
      return const Center(child: Text('No hay partidos', style: TextStyle(color: Colors.white54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _matches.length,
      itemBuilder: (context, index) {
        final match = _matches[index];
        final hasExisting = match['realHomeScore'] != null && match['realAwayScore'] != null;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: hasExisting ? 0.06 : 0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasExisting
                  ? Colors.green.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    MatchConstants.buildTeamLogo(match['localLogo'] ?? '', match['localEmoji'] ?? '', 28),
                    const SizedBox(height: 4),
                    Text(
                      TeamNameUtils.getShortName(match['local'] ?? ''),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: TextField(
                  controller: _homeControllers[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '-',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryPurple),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'VS',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 48,
                child: TextField(
                  controller: _awayControllers[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '-',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryPurple),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    MatchConstants.buildTeamLogo(match['visitorLogo'] ?? '', match['visitorEmoji'] ?? '', 28),
                    const SizedBox(height: 4),
                    Text(
                      TeamNameUtils.getShortName(match['visitor'] ?? ''),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveResults,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text(
                  'GUARDAR RESULTADOS',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
        ),
      ),
    );
  }
}
