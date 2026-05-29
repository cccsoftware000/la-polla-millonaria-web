// splash_screen.dart - VERSIÓN CORREGIDA

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../services/analytics_service.dart';
import '../../services/github_update_service.dart';
import '../../widgets/update_dialog.dart';
import '../auth/auth_gate.dart';
import '../onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController scaleController;
  late AnimationController glowController;
  late AnimationController rotationController;
  late Animation<double> scaleAnimation;
  late Animation<double> rotationAnimation;

  bool _isNavigating = false;
  bool _hasUpdate = false;

  @override
  void initState() {
    super.initState();

    AnalyticsService.logScreen(screenName: 'splash_screen');

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    scaleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    scaleAnimation = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: scaleController, curve: Curves.elasticOut),
    );

    glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: rotationController, curve: Curves.linear),
    );

    scaleController.forward();

    // ✅ Primero verificar actualizaciones, luego navegar
    _checkUpdatesAndNavigate();
  }

  @override
  void dispose() {
    scaleController.dispose();
    glowController.dispose();
    rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              AppColors.primaryPurple,
              AppColors.midnightBlue,
              AppColors.background,
            ],
            stops: const [0.2, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            ..._buildBackgroundGlows(),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo animado
                    AnimatedBuilder(
                      animation: rotationAnimation,
                      builder: (context, _) {
                        return Transform.rotate(
                          angle: rotationAnimation.value * 2 * 3.14159,
                          child: AnimatedBuilder(
                            animation: scaleAnimation,
                            builder: (context, _) {
                              return Transform.scale(
                                scale: scaleAnimation.value,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.primaryPurple,
                                        AppColors.energeticRed,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.energeticRed
                                            .withValues(alpha: 0.6),
                                        blurRadius: 50,
                                        spreadRadius: 15,
                                      ),
                                      BoxShadow(
                                        color: AppColors.primaryPurple
                                            .withValues(alpha: 0.4),
                                        blurRadius: 30,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: AnimatedBuilder(
                                    animation: glowController,
                                    builder: (context, _) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.energeticRed
                                                  .withValues(
                                                    alpha:
                                                        0.3 +
                                                        (glowController.value *
                                                            0.3),
                                                  ),
                                              blurRadius:
                                                  30 +
                                                  (glowController.value * 20),
                                              spreadRadius:
                                                  5 +
                                                  (glowController.value * 10),
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: Image.asset(
                                            'assets/logo/logoApp.png',
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return const Center(
                                                    child: Text(
                                                      '⚽',
                                                      style: TextStyle(
                                                        fontSize: 65,
                                                      ),
                                                    ),
                                                  );
                                                },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Título principal
                    TweenAnimationBuilder(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: const Text(
                        'LA POLLA\nMILLONARIA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              color: AppColors.primaryPurple,
                              blurRadius: 15,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Subtítulo animado
                    TweenAnimationBuilder(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(opacity: value, child: child);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.1),
                              Colors.white.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          'Predice. Gana. Vibra.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 60),

                    // Indicador de carga premium
                    TweenAnimationBuilder(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(seconds: 2),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Column(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                child: const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primaryPurple,
                                  ),
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Cargando experiencia premium...',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 12,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBackgroundGlows() {
    return [
      Positioned(
        top: -80,
        left: -80,
        child: AnimatedBuilder(
          animation: glowController,
          builder: (context, _) {
            return Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryPurple.withValues(
                  alpha: 0.1 + (glowController.value * 0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withValues(alpha: 0.2),
                    blurRadius: 80,
                    spreadRadius: 30,
                  ),
                ],
              ),
            );
          },
        ),
      ),
      Positioned(
        bottom: -100,
        right: -100,
        child: AnimatedBuilder(
          animation: glowController,
          builder: (context, _) {
            return Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.energeticRed.withValues(
                  alpha: 0.08 + (glowController.value * 0.04),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.energeticRed.withValues(alpha: 0.15),
                    blurRadius: 100,
                    spreadRadius: 40,
                  ),
                ],
              ),
            );
          },
        ),
      ),
      Positioned(
        top: 200,
        right: -60,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.purple.withValues(alpha: 0.06),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withValues(alpha: 0.1),
                blurRadius: 60,
                spreadRadius: 20,
              ),
            ],
          ),
        ),
      ),
    ];
  }

  // ✅ Método principal: primero verifica actualizaciones, luego navega
  Future<void> _checkUpdatesAndNavigate() async {
    await Future.delayed(const Duration(seconds: 1));
    if (kIsWeb) {
      await _navigateToNextScreen();
      return;
    } else {
      try {
        final updateService = GitHubUpdateService();
        final release = await updateService.checkForUpdates();

        if (release != null && mounted) {
          // ✅ Si es obligatoria, no se puede cerrar el diálogo
          final shouldUpdate = await showDialog<bool>(
            context: context,
            barrierDismissible:
                !release.isRequired, // ✅ No se puede cerrar tocando fuera
            builder: (_) => UpdateDialog(release: release, onUpdate: () {}),
          );

          // Si el usuario canceló una actualización no obligatoria, navegar
          if (shouldUpdate == null && !release.isRequired) {
            // Usuario canceló, navegar igual
          } else if (release.isRequired) {
            // Si es obligatoria, esperar a que actualice
            return;
          }
        }
      } catch (e) {
        print('Error checking updates: $e');
      }
      if (mounted) {
        await _navigateToNextScreen();
      }
    }
  }

  Future<void> _navigateToNextScreen() async {
    if (_isNavigating) return;
    _isNavigating = true;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    if (!mounted) return;

    if (hasSeenOnboarding) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AuthGate(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }
}
