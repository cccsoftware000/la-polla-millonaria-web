// lib/widgets/animated_accumulated_card.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/matches_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/date_utils.dart';
import '../models/global_settings_model.dart';
import '../services/accumulated_service.dart';

class AnimatedAccumulatedCard extends StatefulWidget {
  final Stream<GlobalSettingsModel> accumulatedStream;

  const AnimatedAccumulatedCard({super.key, required this.accumulatedStream});

  @override
  State<AnimatedAccumulatedCard> createState() =>
      _AnimatedAccumulatedCardState();
}

class _AnimatedAccumulatedCardState extends State<AnimatedAccumulatedCard>
    with TickerProviderStateMixin {
  GlobalSettingsModel? _lastSettings;

  int _lastValue = 0;
  int _currentValue = 0;
  int _lastIncrease = 0;
  bool _showIncreaseAnimation = false;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _slideController;
  late AnimationController _balloonController; // ✅ Para animación del balón
  late Animation<double> _scaleAnimation;
  late Animation<double> _balloonScaleAnimation;
  Timer? _hideAnimationTimer;
  Timer? _countdownTimer;
  String _countdownText = 'Cargando...';

  // ✅ Para tracking del récord
  int _highestAccumulated = 0;
  bool _showRecordAnimation = false;

  // ✅ Control para evitar setState durante build
  bool _isBuilding = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // ✅ Animación de respiración para el balón
    _balloonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _balloonScaleAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _balloonController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateCountdown();
      }
    });
    _updateCountdown();
  }

  void _updateCountdown() {
    final nearestDate = MatchConstants.getNearestClosingDate();
    if (nearestDate != null) {
      setState(() {
        _countdownText = DateUtilsApp.getRemainingTime(nearestDate);
      });
    } else {
      setState(() {
        _countdownText = 'Torneo finalizado';
      });
    }
  }

  void _onAccumulatedUpdate(GlobalSettingsModel settings) {
    final newValue = settings.currentAccumulated;
    final increase = settings.lastAccumulatedIncrease;

    // ✅ Verificar récord
    if (newValue > _highestAccumulated) {
      _highestAccumulated = newValue;
      _showRecordAnimation = true;
      _hideAnimationTimer?.cancel();
      _hideAnimationTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && !_isBuilding) {
          setState(() {
            _showRecordAnimation = false;
          });
        }
      });
    }

    // ✅ Evitar setState si ya estamos en build
    if (_isBuilding) return;

    if (newValue != _currentValue && _currentValue != 0) {
      // Hubo un aumento
      _lastIncrease = increase;
      _showIncreaseAnimation = true;
      _currentValue = newValue;

      _pulseController.forward().then((_) => _pulseController.reset());
      _slideController.forward().then((_) {
        _slideController.reset();
      });

      _hideAnimationTimer?.cancel();
      _hideAnimationTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && !_isBuilding) {
          setState(() {
            _showIncreaseAnimation = false;
          });
        }
      });
    } else {
      _currentValue = newValue;
    }
    _lastValue = newValue;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _slideController.dispose();
    _balloonController.dispose();
    _hideAnimationTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatNumber(int number) {
    // ✅ Formato con separadores de miles
    final formatter = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    return formatter.format(number);

    // Versión manual si no quieres usar NumberFormat:
    // final formatter = NumberFormat('#,##0', 'es_CO');
    // return '\$${formatter.format(number)}';
  }

  @override
  Widget build(BuildContext context) {
    _isBuilding = true;

    return StreamBuilder<GlobalSettingsModel>(
      stream: widget.accumulatedStream,
      builder: (context, snapshot) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isBuilding = false;
          if (snapshot.hasData && mounted) {
            _onAccumulatedUpdate(snapshot.data!);
          }
        });

        if (!snapshot.hasData) {
          return _buildLoadingCard();
        }

        final settings = snapshot.data!;

        return AnimatedBuilder(
          animation: _glowController,
          builder: (context, _) {
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(
                  colors: [AppColors.primaryPurple, AppColors.energeticRed],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.energeticRed.withValues(
                      alpha: 0.35 + (_glowController.value * 0.25),
                    ),
                    blurRadius: 25 + (_glowController.value * 15),
                    spreadRadius: 2 + (_glowController.value * 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // ✅ Badge de récord (si aplica)
                    if (_showRecordAnimation)
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 500),
                        opacity: 1.0,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events, size: 16, color: Colors.black),
                              SizedBox(width: 6),
                              Text(
                                '¡NUEVO RÉCORD!',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const Text(
                      'ACUMULADO ACTUAL',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ✅ Balón animado (respiración)
                    AnimatedBuilder(
                      animation: _balloonScaleAnimation,
                      builder: (context, _) {
                        return Transform.scale(
                          scale: _balloonScaleAnimation.value,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                '⚽',
                                style: TextStyle(fontSize: 38),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // ✅ Monto con animación
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, _) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Column(
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1,
                                  shadows: _showIncreaseAnimation
                                      ? [
                                    Shadow(
                                      color: Colors.greenAccent
                                          .withValues(alpha: 0.8),
                                      blurRadius: 12,
                                    ),
                                  ]
                                      : null,
                                ),
                                child: Text(
                                  _formatNumber(
                                    _currentValue == 0
                                        ? settings.currentAccumulated
                                        : _currentValue,
                                  ),
                                ),
                              ),

                              // ✅ Animación de aumento
                              if (_showIncreaseAnimation)
                                AnimatedBuilder(
                                  animation: _slideController,
                                  builder: (context, _) {
                                    return Transform.translate(
                                      offset: Offset(
                                        0,
                                        -15 * (1 - _slideController.value),
                                      ),
                                      child: Opacity(
                                        opacity: _slideController.value > 0.8
                                            ? 1 -
                                            (_slideController.value -
                                                0.8) *
                                                5
                                            : 1,
                                        child: Container(
                                          margin: const EdgeInsets.only(top: 6),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.greenAccent
                                                .withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: Colors.greenAccent
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.trending_up,
                                                color: Colors.greenAccent,
                                                size: 12,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '+ ${_formatNumber(_lastIncrease)}',
                                                style: const TextStyle(
                                                  color: Colors.greenAccent,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // ✅ Countdown badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Cierra en: $_countdownText',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [AppColors.primaryPurple, AppColors.energeticRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'ACUMULADO ACTUAL',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}