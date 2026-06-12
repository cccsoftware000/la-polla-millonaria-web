import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _getErrorMessage(String code) {
    switch (code) {
      case 'unauthenticated':
        return 'Usuario no autenticado';
      case 'permission-denied':
        return 'No tienes permiso para realizar esta acción';
      case 'network-error':
        return 'Error de conexión. Verifica tu internet';
      default:
        return 'Error inesperado. Intenta nuevamente';
    }
  }

  Future<void> createUser({
    required String name,
    required String avatar,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      if (name.trim().isEmpty) {
        throw Exception('El nombre no puede estar vacío');
      }

      if (name.length > 20) {
        throw Exception('El nombre es demasiado largo (máximo 20 caracteres)');
      }

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'phone': user.phoneNumber ?? '',
        'name': name.trim(),
        'avatar': avatar,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception(_getErrorMessage(e.code));
    } catch (e) {
      throw Exception('Error al crear el usuario: $e');
    }
  }

  Future<bool> userExists() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.exists;
    } on FirebaseException catch (e) {
      print('Error checking user exists: ${e.code}');
      return false;
    } catch (e) {
      print('Error inesperado: $e');
      return false;
    }
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) return null;

      return UserModel.fromMap(doc.data()!);
    } on FirebaseException catch (e) {
      print('Error getting current user: ${e.code}');
      return null;
    } catch (e) {
      print('Error inesperado: $e');
      return null;
    }
  }

  Future<bool> updateUserName(String newName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      if (newName.trim().isEmpty) {
        throw Exception('El nombre no puede estar vacío');
      }

      if (newName.length > 20) {
        throw Exception('El nombre es demasiado largo (máximo 20 caracteres)');
      }

      await _firestore.collection('users').doc(user.uid).update({
        'name': newName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating user name: $e');
      return false;
    }
  }

  Future<bool> updateUserAvatar(String newAvatar) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('users').doc(user.uid).update({
        'avatar': newAvatar,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating user avatar: $e');
      return false;
    }
  }

  Stream<UserModel?> streamCurrentUser() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return UserModel.fromMap(doc.data()!);
        })
        .handleError((error) {
          print('Stream error: $error');
          return null;
        });
  }

  // lib/services/user_service.dart (agrega estos métodos)

  // ✅ Actualizar último login
  Future<void> updateLastLogin() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  // ✅ Desactivar cuenta (soft delete)
  Future<bool> deactivateAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('users').doc(user.uid).update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error deactivating account: $e');
      return false;
    }
  }

  // ✅ Actualizar preferencias de notificaciones
  Future<bool> updateNotificationPreference(bool enabled) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('users').doc(user.uid).update({
        'pushNotificationsEnabled': enabled,
      });
      return true;
    } catch (e) {
      print('Error updating notification preference: $e');
      return false;
    }
  }

  // ✅ Eliminar cuenta permanentemente (solo después de verificar)
  Future<bool> deleteAccountPermanently() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // 1. Eliminar todas las apuestas del usuario (soft delete)
      final bets = await _firestore
          .collection('bets')
          .where('uid', isEqualTo: user.uid)
          .get();

      final batch = _firestore.batch();
      for (var doc in bets.docs) {
        batch.update(doc.reference, {
          'deleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedReason': 'user_account_deleted',
        });
      }
      await batch.commit();

      // 2. Marcar usuario como eliminado
      await _firestore.collection('users').doc(user.uid).update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
        'deleted': true,
      });

      // 3. Eliminar autenticación (requiere reautenticación)
      await user.delete();

      return true;
    } catch (e) {
      print('Error deleting account: $e');
      return false;
    }
  }

  // ✅ Reautenticar usuario antes de acciones sensibles
  Future<bool> reauthenticateUser(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return false;

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      print('Reauthentication failed: $e');
      return false;
    }
  }

  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!);
    } catch (e) {
      print('Error getting user by id: $e');
      return null;
    }
  }

  Future<bool> isAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;

      final role = doc.data()!['role'] as String?;
      return role == 'admin';
    } catch (e) {
      print('Error checking admin role: $e');
      return false;
    }
  }

  Future<bool> checkAdminRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      final role = doc.data()!['role'] as String?;
      return role == 'admin';
    } catch (e) {
      print('Error checking admin role: $e');
      return false;
    }
  }

  // lib/services/user_service.dart

// Agregar estos métodos

  /// Actualizar experiencia del usuario al pagar una apuesta
  Future<void> updateUserExperienceOnPayment(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final user = UserModel.fromMap(userDoc.data()!);
      final newTotalBetsPaid = user.totalBetsPaid + 1;
      final expGain = 50; // 50 XP por apuesta pagada
      final newExp = user.experiencePoints + expGain;
      final newLevel = _calculateLevel(newExp);

      await _firestore.collection('users').doc(userId).update({
        'totalBetsPaid': newTotalBetsPaid,
        'experiencePoints': newExp,
        'level': newLevel,
      });
    } catch (e) {
      print('Error updating user experience: $e');
    }
  }

  /// Actualizar experiencia al ganar una apuesta
  Future<void> updateUserExperienceOnWin(String userId, int prize) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final user = UserModel.fromMap(userDoc.data()!);
      final newTotalBetsWon = user.totalBetsWon + 1;
      final expGain = 100 + (prize ~/ 10000); // XP base + bonificación por premio
      final newExp = user.experiencePoints + expGain;
      final newLevel = _calculateLevel(newExp);

      await _firestore.collection('users').doc(userId).update({
        'totalBetsWon': newTotalBetsWon,
        'experiencePoints': newExp,
        'level': newLevel,
      });
    } catch (e) {
      print('Error updating user experience on win: $e');
    }
  }

  int _calculateLevel(int exp) {
    if (exp >= 12000) return 10;
    if (exp >= 8000) return 9;
    if (exp >= 5500) return 8;
    if (exp >= 3500) return 7;
    if (exp >= 2000) return 6;
    if (exp >= 1000) return 5;
    if (exp >= 500) return 4;
    if (exp >= 250) return 3;
    if (exp >= 100) return 2;
    return 1;
  }
}
