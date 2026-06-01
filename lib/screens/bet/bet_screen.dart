// lib/screens/bet/bet_screen.dart (VERSIÓN ACTUALIZADA)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/matches_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../services/analytics_service.dart';
import '../../services/bet_service.dart';
import '../../services/cache_service.dart';
import '../../services/polla_service.dart';
import '../../services/match_service.dart';
import '../../models/polla_model.dart';
import '../../models/match_model.dart';
import '../../widgets/bet/loading_bet_dialog.dart';
import '../../models/bet_model.dart';

class BetScreen extends StatefulWidget {
  final BetModel? betToEdit;

  const BetScreen({super.key, this.betToEdit});

  @override
  State<BetScreen> createState() => _BetScreenState();
}

class _BetScreenState extends State<BetScreen> with TickerProviderStateMixin {
  bool _dataLoaded = false;
  bool _isSubmitting = false;

  final BetService betService = BetService();
  final PollaService _pollaService = PollaService();
  final MatchService _matchService = MatchService();

  bool get isEditing => widget.betToEdit != null;

  late AnimationController glowController;
  late AnimationController buttonController;
  late Animation<double> buttonScale;
  Timer? _countdownTimer;

  // Estado dinámico
  PollaModel? _activePolla;
  List<MatchModel> _matches = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Controladores dinámicos
  late List<TextEditingController> localControllers;
  late List<TextEditingController> visitorControllers;
  late List<FocusNode> localFocusNodes;
  late List<FocusNode> visitorFocusNodes;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreen(screenName: 'bet_screen');
    _loadData();
    _initializeControllers();
    _loadActivePolla();
    _setupAnimations();
  }

  Future<void> _loadData() async {
    if (_dataLoaded) return; // ✅ Evita recargas múltiples

    setState(() => _isLoading = true);

    // ✅ Intentar cargar desde cache primero
    final cachedMatches = await CacheService.getCachedMatches();
    final cachedPolla = await CacheService.getCachedPolla();

    if (cachedMatches != null && cachedPolla != null) {
      MatchConstants.setMatches(cachedMatches, pollaId: cachedPolla.id);
      setState(() {
        _activePolla = cachedPolla;
        _isLoading = false;
        _dataLoaded = true;
      });
      return;
    }

    // Si no hay cache, cargar desde Firestore
    await _loadActivePolla();
    _dataLoaded = true;
  }

  void _initializeControllers() {
    // Inicialización temporal, se recalculará cuando carguen los partidos
    localControllers = [];
    visitorControllers = [];
    localFocusNodes = [];
    visitorFocusNodes = [];
  }

  void _reinitializeControllers(int count) {
    // Liberar controladores anteriores
    for (var c in localControllers) { c.dispose(); }
    for (var c in visitorControllers) { c.dispose(); }
    for (var f in localFocusNodes) { f.dispose(); }
    for (var f in visitorFocusNodes) { f.dispose(); }

    // Crear nuevos controladores
    localControllers = List.generate(count, (_) => TextEditingController());
    visitorControllers = List.generate(count, (_) => TextEditingController());
    localFocusNodes = List.generate(count, (_) => FocusNode());
    visitorFocusNodes = List.generate(count, (_) => FocusNode());

    // ✅ CORREGIDO: Cargar valores de edición
    if (isEditing && widget.betToEdit != null) {
      final predictions = widget.betToEdit!.predictions;
      print('📝 Editando apuesta con ${predictions.length} predicciones');

      for (int i = 0; i < predictions.length && i < count; i++) {
        final prediction = predictions[i];
        final homeScore = prediction['homeScore']?.toString() ?? '0';
        final awayScore = prediction['awayScore']?.toString() ?? '0';

        localControllers[i].text = homeScore;
        visitorControllers[i].text = awayScore;

        print('  Partido ${i+1}: $homeScore - $awayScore');
      }
    } else {
      // Inicializar con "0" para nueva apuesta
      for (int i = 0; i < count; i++) {
        localControllers[i].text = "0";
        visitorControllers[i].text = "0";
      }
    }
  }

  void _setupAnimations() {
    glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    buttonController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    buttonScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: buttonController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadActivePolla() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final polla = await _pollaService.getActivePolla();

      if (polla == null) {
        setState(() {
          _errorMessage = 'No hay una polla activa en este momento.\nVuelve más tarde.';
          _isLoading = false;
        });
        return;
      }

      // Verificar si aún se puede apostar (saltar si es edición)
      if (!isEditing) {
        final canBet = await _matchService.canBetOnPolla(polla.id);
        if (!canBet) {
          setState(() {
            _errorMessage = 'La polla ya cerró. Los partidos ya comenzaron.';
            _isLoading = false;
          });
          return;
        }
      }

      // Obtener partidos y convertir a Map
      final matchesData = await _matchService.getMatchesForBetScreen(polla.id);

      if (matchesData.isEmpty) {
        setState(() {
          _errorMessage = 'No hay partidos configurados para esta polla.';
          _isLoading = false;
        });
        return;
      }

      // Actualizar MatchConstants
      MatchConstants.setMatches(matchesData, pollaId: polla.id);

      // ✅ Reinitializar controladores (esto conserva los valores de edición)
      _reinitializeControllers(matchesData.length);

      setState(() {
        _activePolla = polla;
        _isLoading = false;
      });

      _startCountdownTimer();

    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar la polla: $e';
        _isLoading = false;
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    for (var c in localControllers) { c.dispose(); }
    for (var c in visitorControllers) { c.dispose(); }
    for (var f in localFocusNodes) { f.dispose(); }
    for (var f in visitorFocusNodes) { f.dispose(); }
    glowController.dispose();
    buttonController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

      final matches = MatchConstants.getAllMatches(pollaId: _activePolla?.id);
      if (matches.isEmpty) {
      return _buildEmptyScreen();
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [AppColors.primaryPurple, AppColors.midnightBlue, AppColors.background],
            stops: const [0.1, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            _buildBackgroundGlows(),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildPrizeCard(),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      physics: const BouncingScrollPhysics(),
                      itemCount: matches.length,
                      itemBuilder: (_, index) => _buildMatchCard(index, pollaId: _activePolla?.id),
                    ),
                  ),
                  _buildConfirmButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [AppColors.primaryPurple, AppColors.midnightBlue, AppColors.background],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primaryPurple),
              SizedBox(height: 16),
              Text('Cargando polla activa...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [AppColors.primaryPurple, AppColors.midnightBlue, AppColors.background],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadActivePolla,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('REINTENTAR'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [AppColors.primaryPurple, AppColors.midnightBlue, AppColors.background],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sports_soccer, color: Colors.white54, size: 64),
              SizedBox(height: 16),
              Text('No hay partidos disponibles', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -80,
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
          bottom: -120,
          right: -100,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Editar\nApuesta' : (_activePolla?.name ?? 'La Polla\nMillonaria'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                if (_activePolla != null)
                  Text(
                    'Cierra: ${DateUtilsApp.formatMatchDateTime(_activePolla!.endDate)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeCard() {
    final globalCountdown = MatchConstants.getGlobalCountdown();
    final isAnyMatchOpen = !MatchConstants.areAllMatchesClosed();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [AppColors.primaryPurple, AppColors.energeticRed],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [BoxShadow(color: AppColors.energeticRed.withValues(alpha: 0.35), blurRadius: 20, spreadRadius: 1)],
        ),
        child: Column(
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: glowController,
                  builder: (context, _) => Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15 + (glowController.value * 0.05)),
                    ),
                    child: const Center(child: Text('⚽', style: TextStyle(fontSize: 28))),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\$${_activePolla?.prizeAmount ?? 25000000}',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      const Text('Premio acumulado', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            if (isAnyMatchOpen) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'Cierra en: $globalCountdown',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMatchCard(int index, {String? pollaId}) {
    final match = MatchConstants.getMatchByIndex(index, pollaId: pollaId);
    final isClosed = MatchConstants.isMatchClosed(index, pollaId: pollaId);

    // ✅ Obtener la fecha UTC del match y formatearla correctamente
    final utcDateTime = match['dateTime'] as DateTime;
    final formattedDateTime = DateUtilsApp.formatMatchDateTime(utcDateTime);
    final timeRemaining = DateUtilsApp.getRemainingTime(utcDateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isClosed ? Colors.white.withValues(alpha: 0.02) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isClosed ? Colors.redAccent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Fecha y hora CORREGIDA - usando DateUtilsApp
          Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.white.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  formattedDateTime,  // ✅ Ahora muestra "mar, 26 de may - 19:30" en hora Colombia
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                ),
              ),
            ],
          ),

          // Tiempo restante
          if (!isClosed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, size: 12, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    "Cierra en: $timeRemaining",
                    style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 12, color: Colors.redAccent),
                  SizedBox(width: 4),
                  Text("Partido cerrado", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Equipos
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    MatchConstants.buildTeamLogo(match["localLogo"], match["localEmoji"], 48),
                    const SizedBox(height: 10),
                    Text(
                      match["local"],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isClosed ? Colors.white.withValues(alpha: 0.5) : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: isClosed ? Colors.white.withValues(alpha: 0.3) : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    MatchConstants.buildTeamLogo(match["visitorLogo"], match["visitorEmoji"], 48),
                    const SizedBox(height: 10),
                    Text(
                      match["visitor"],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isClosed ? Colors.white.withValues(alpha: 0.5) : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 18),

          // Marcadores
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildScoreButton(localControllers[index], localFocusNodes[index], index, true, isClosed, pollaId: pollaId),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'FINAL',
                  style: TextStyle(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              _buildScoreButton(visitorControllers[index], visitorFocusNodes[index], index, false, isClosed, pollaId: pollaId),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreButton(TextEditingController controller, FocusNode focusNode, int index, bool isLocal, bool isClosed, {String? pollaId}) {
    int value = int.tryParse(controller.text) ?? 0;

    void updateValue(int newValue) {
      if (newValue < 0) newValue = 0;
      if (newValue > 20) newValue = 20;
      controller.text = newValue.toString();
      setState(() {});
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isClosed ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: isClosed ? 0.05 : 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: isClosed ? null : () => updateValue(value - 1),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isClosed ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.remove, color: isClosed ? Colors.white24 : Colors.white70, size: 18),
            ),
          ),
          SizedBox(
            width: 44,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 2,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                color: isClosed ? Colors.white.withValues(alpha: 0.5) : Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              enabled: !isClosed,
              onChanged: (val) {
                if (isClosed) return;
                final parsed = int.tryParse(val);
                if (parsed != null && parsed <= 20) {
                  updateValue(parsed);
                } else if (val.isEmpty) {
                  updateValue(0);
                }
                if (isLocal) {
                  FocusScope.of(context).requestFocus(visitorFocusNodes[index]);
                } else if (index < MatchConstants.getMatchCount(pollaId: pollaId) - 1) {
                  FocusScope.of(context).requestFocus(localFocusNodes[index + 1]);
                }
              },
            ),
          ),
          GestureDetector(
            onTap: isClosed ? null : () => updateValue(value + 1),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: isClosed
                    ? null
                    : const LinearGradient(
                  colors: [AppColors.primaryPurple, AppColors.energeticRed],
                ),
                color: isClosed ? Colors.white.withValues(alpha: 0.05) : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.add, color: isClosed ? Colors.white24 : Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    final allClosed = MatchConstants.areAllMatchesClosed();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: AnimatedBuilder(
        animation: buttonScale,
        builder: (context, _) {
          return Transform.scale(
            scale: buttonScale.value,
            child: GestureDetector(
              onTapDown: allClosed ? null : (_) => buttonController.forward(),
              onTapUp: allClosed ? null : (_) => buttonController.reverse(),
              onTapCancel: allClosed ? null : () => buttonController.reverse(),
              onTap: allClosed ? null : _handleConfirmBet,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: allClosed
                      ? null
                      : const LinearGradient(
                    colors: [AppColors.primaryPurple, AppColors.energeticRed],
                  ),
                  color: allClosed ? Colors.grey : null,
                  boxShadow: allClosed
                      ? null
                      : [BoxShadow(color: AppColors.energeticRed.withValues(alpha: 0.4), blurRadius: 15, spreadRadius: 1)],
                ),
                child: Center(
                  child: Text(
                    isEditing ? 'ACTUALIZAR APUESTA' : 'CONFIRMAR APUESTA',
                    style: TextStyle(
                      color: allClosed ? Colors.white54 : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleConfirmBet() async {
    final matches = MatchConstants.getAllMatches(pollaId: _activePolla?.id);

    // Verificar si la polla sigue activa
    if (_activePolla != null) {
      final isStillActive = await _pollaService.isPollaOpen(_activePolla!.id);
      if (!isStillActive) {
        _showErrorSnackbar('La polla ya cerró. No se pueden registrar nuevas apuestas.');
        return;
      }
    }

    // Verificar si algún partido ya cerró
    for (int i = 0; i < matches.length; i++) {
      if (MatchConstants.isMatchClosed(i, pollaId: _activePolla?.id)) {
        _showErrorSnackbar('El partido ${matches[i]['local']} vs ${matches[i]['visitor']} ya cerró. No se puede apostar.');
        return;
      }
    }

    List<Map<String, dynamic>> predictions = [];

    for (int i = 0; i < matches.length; i++) {
      final home = localControllers[i].text.trim();
      final away = visitorControllers[i].text.trim();

      final homeScore = int.tryParse(home);
      final awayScore = int.tryParse(away);

      if (homeScore == null || awayScore == null || homeScore > 20 || awayScore > 20) {
        _showErrorSnackbar('Marcador inválido en el partido ${i + 1} (use números del 0 al 20)');
        return;
      }

      // ✅ CORREGIDO: Usar el ID real del match, no el índice
      final matchId = matches[i]['id'] as String;
      predictions.add({
        'matchId': matchId,
        'homeScore': homeScore,
        'awayScore': awayScore,
      });
    }

    if (!isEditing) {
      final pendingCount = await betService.getPendingBetsCount();
      if (pendingCount >= 2) {
        _showErrorSnackbar('Ya tienes 2 apuestas pendientes. Paga tu apuesta actual.');
        return;
      }
    }

    _showConfirmationDialog(predictions);
  }

  void _showConfirmationDialog(List<Map<String, dynamic>> predictions) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(isEditing ? 'Editar apuesta' : 'Confirmar apuesta', style: const TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEditing ? '¿Estás seguro de editar esta apuesta?' : '¿Estás seguro de registrar esta apuesta?',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
              child: Text(
                'Premio: \$${_activePolla?.prizeAmount ?? 25000000}',
                style: const TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR', style: TextStyle(color: Colors.white54, fontSize: 13))),
          ElevatedButton(
            onPressed: () => _submitBet(predictions),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('CONFIRMAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitBet(List<Map<String, dynamic>> predictions) async {
    if (!mounted) return;

    // Prevenir múltiples envíos
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    Navigator.pop(context); // Cerrar diálogo de confirmación

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingBetDialog(),
    );

    try {
      if (isEditing) {
        await betService.updateBet(
          betId: widget.betToEdit!.id,
          predictions: predictions,
        );
        await AnalyticsService.logBetUpdated(betId: widget.betToEdit!.id);
      } else {
        await betService.createBet(
          predictions: predictions,
          pollaId: _activePolla?.id ?? 'jornada_1',  // 👈 Pasar la pollaId
        );
        await AnalyticsService.logBetCreated();
      }

      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading

      // ✅ Diálogo de éxito corregido
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('¡Apuesta registrada!', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: const Text(
            'Tu apuesta quedó pendiente de pago.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Cerrar diálogo
                Navigator.pop(context, true); // Volver
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryPurple,
              ),
              child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loading
      setState(() => _isSubmitting = false);
      _showErrorSnackbar(e.toString());
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.error_outline, color: Colors.white, size: 18), const SizedBox(width: 10), Expanded(child: Text(message))]),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}