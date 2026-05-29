// lib/screens/auth/welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../home/home_screen.dart';
import '../register/register_profile_screen.dart';
import 'email_login_screen.dart';
import 'email_register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final AuthService _auth = AuthService();
  final UserService _userService = UserService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAlreadyLoggedIn();
  }

  Future<void> _checkAlreadyLoggedIn() async {
    if (_auth.currentUser != null) {
      final exists = await _userService.userExists();
      if (exists && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final result = await _auth.signInWithGoogle();

      if (result.user != null) {
        final exists = await _userService.userExists();
        if (mounted) {
          if (exists) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          } else {
            // En web, pasar el email y nombre de Google al registro
            final email = result.user!.email ?? '';
            final name = result.user!.displayName ?? '';

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => RegisterProfileScreen(
                  prefillEmail: email,
                  prefillName: name,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (kIsWeb && e.toString().contains('popup')) {
        _showError('El popup fue bloqueado. Permite ventanas emergentes.');
      } else {
        _showError(e.toString());
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryPurple, AppColors.energeticRed],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.energeticRed.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('⚽', style: TextStyle(fontSize: 50)),
                  ),
                ),

                const SizedBox(height: 32),

                const Text(
                  'La Polla Millonaria',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                const Text(
                  'Predice. Gana. Vibra.',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),

                const Spacer(flex: 1),

                // Botón Email Login
                _buildAuthButton(
                  icon: Icons.email,
                  label: 'Iniciar sesión con Email',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EmailLoginScreen()),
                    );
                  },
                  color: Colors.blue,
                ),

                const SizedBox(height: 12),

                // Botón Email Register
                _buildAuthButton(
                  icon: Icons.person_add,
                  label: 'Crear cuenta con Email',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EmailRegisterScreen()),
                    );
                  },
                  color: Colors.green,
                ),

                const SizedBox(height: 12),

                // Botón Google
                _buildAuthButton(
                  icon: Icons.g_mobiledata,
                  label: 'Continuar con Google',
                  onTap: _handleGoogleSignIn,
                  color: Colors.red,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 32),

                // Términos
                Text(
                  'Al continuar aceptas nuestros Términos y Condiciones',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
                  textAlign: TextAlign.center,
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          color: Colors.white.withValues(alpha: 0.05),
        ),
        child: isLoading
            ? const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}