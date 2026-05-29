// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:la_polla_millonaria/screens/profile/stats_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/bet_status.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../services/bet_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/profile/profile_header.dart';
import '../../widgets/profile/profile_menu_item.dart';
import '../auth/welcome_screen.dart';
import 'bet_history_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final BetService _betService = BetService();
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = true;
  int _totalBets = 0;
  int _wonBets = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    final user = await _userService.getCurrentUser();
    final allBets = await _betService.getUserBets();

    setState(() {
      _user = user;
      _totalBets = allBets.length;
      _wonBets = allBets.where((b) => b.status == BetStatus.winner).length;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Cerrar sesión',
      message: '¿Estás seguro de que quieres cerrar sesión?',
      confirmText: 'CERRAR',
      cancelText: 'CANCELAR',
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              (route) => false,
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    // Primero pedir confirmación
    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Eliminar cuenta',
      message: 'Esta acción es irreversible. Se eliminarán todas tus apuestas y datos.',
      confirmText: 'ELIMINAR',
      cancelText: 'CANCELAR',
      isDestructive: true,
    );

    if (confirm != true) return;

    // Si usa email, pedir contraseña para reautenticar
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      final password = await _showPasswordDialog();
      if (password == null || password.isEmpty) return;

      final reauthenticated = await _userService.reauthenticateUser(password);
      if (!reauthenticated) {
        _showError('Contraseña incorrecta');
        return;
      }
    }

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryPurple),
      ),
    );

    final deleted = await _userService.deleteAccountPermanently();

    if (mounted) Navigator.pop(context);

    if (deleted) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              (route) => false,
        );
      }
    } else {
      _showError('Error al eliminar la cuenta. Intenta nuevamente.');
    }
  }

  Future<String?> _showPasswordDialog() async {
    TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Confirmar contraseña',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Tu contraseña',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryPurple),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
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
    if (_isLoading || _user == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

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
          'Mi Perfil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ProfileHeader(
              user: _user!,
              onEditAvatar: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(user: _user!),
                  ),
                );
                if (result == true) _loadUserData();
              },
              onEditName: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(user: _user!),
                  ),
                );
                if (result == true) _loadUserData();
              },
            ),
            const SizedBox(height: 24),

            // Estadísticas
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  _buildStatItem('Apuestas', _totalBets.toString(), Icons.sports_soccer),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  _buildStatItem('Ganadas', _wonBets.toString(), Icons.emoji_events),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  _buildStatItem('Efectividad', '${_totalBets > 0 ? ((_wonBets / _totalBets) * 100).toInt() : 0}%', Icons.trending_up),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Menú de opciones
            ProfileMenuItem(
              icon: Icons.person_outline,
              title: 'Editar perfil',
              subtitle: 'Cambiar nombre y avatar',
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(user: _user!),
                  ),
                );
                if (result == true) _loadUserData();
              },
            ),
            ProfileMenuItem(
              icon: Icons.history,
              title: 'Historial de apuestas',
              subtitle: 'Ver todas tus apuestas anteriores',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BetHistoryScreen()),
                );
              },
            ),
            ProfileMenuItem(
              icon: Icons.bar_chart,
              title: 'Estadísticas',
              subtitle: 'Tu rendimiento en la polla',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatsScreen()),
                );
              },
            ),
            ProfileMenuItem(
              icon: Icons.notifications_outlined,
              title: 'Notificaciones',
              subtitle: 'Configurar alertas',
              onTap: () {
                // TODO: Configuración de notificaciones
              },
              trailing: Switch(
                value: _user?.pushNotificationsEnabled ?? true,
                onChanged: (value) async {
                  await _userService.updateNotificationPreference(value);
                  _loadUserData();
                },
                activeColor: AppColors.primaryPurple,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 16),
            ProfileMenuItem(
              icon: Icons.logout,
              title: 'Cerrar sesión',
              iconColor: Colors.orange,
              onTap: _logout,
            ),
            ProfileMenuItem(
              icon: Icons.delete_outline,
              title: 'Eliminar cuenta',
              subtitle: 'Esta acción es irreversible',
              iconColor: Colors.redAccent,
              onTap: _deleteAccount,
            ),
            const SizedBox(height: 30),
            Center(
              child: Text(
                'Versión 1.0.0',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 20),
          const SizedBox(height: 6),
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
    );
  }
}