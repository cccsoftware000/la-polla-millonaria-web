// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
// import 'package:sign_in_with_apple/sign_in_with_apple.dart'; // Solo iOS, comentar si no se usa
import 'analytics_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ==================== EMAIL / PASSWORD ====================

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Enviar email de verificación
      await credential.user?.sendEmailVerification();

      await AnalyticsService.logRegister();
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e);
    } catch (e) {
      throw Exception('Error al registrar: $e');
    }
  }

  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Verificar si el email está verificado
      if (!credential.user!.emailVerified) {
        await _auth.signOut();
        throw Exception('Por favor verifica tu email antes de iniciar sesión');
      }

      await AnalyticsService.logLogin();
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e);
    } catch (e) {
      throw Exception('Error al iniciar sesión: $e');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e);
    } catch (e) {
      throw Exception('Error al enviar email de recuperación: $e');
    }
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<bool> isEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // ==================== GOOGLE SIGN-IN ====================

  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // ✅ Versión para WEB (usa FirebaseAuth directamente)
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        return userCredential;
      } else {
        // ✅ Versión para MÓVIL
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) throw Exception('Cancelado por el usuario');

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      print('Error en Google Sign-In: $e');
      rethrow;
    }
  }

  Future<bool> userExists() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // ==================== APPLE SIGN-IN (iOS) ====================
  // Comentar si no se usa en Android
  /*
  Future<UserCredential> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final credential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await AnalyticsService.logLogin();
      return userCredential;
    } catch (e) {
      throw Exception('Error al iniciar con Apple: $e');
    }
  }
  */

  // ==================== PHONE OTP (opcional - para recuperación) ====================
  /*
  Future<void> sendOTPForRecovery(String phone) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: '+57$phone',
      verificationCompleted: (_) {},
      verificationFailed: (_) {},
      codeSent: (verificationId, _) {},
      codeAutoRetrievalTimeout: (_) {},
    );
  }
  */

  // ==================== UTILIDADES ====================

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este email ya está registrado';
      case 'invalid-email':
        return 'Email inválido';
      case 'weak-password':
        return 'La contraseña es muy débil (mínimo 6 caracteres)';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'user-not-found':
        return 'Usuario no encontrado';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde';
      case 'network-request-failed':
        return 'Error de conexión. Verifica tu internet';
      default:
        return e.message ?? 'Error de autenticación';
    }
  }

  User? get currentUser => _auth.currentUser;

  String? get userId => _auth.currentUser?.uid;

  bool get isEmailUser => _auth.currentUser?.email != null;

  bool get isPhoneUser => _auth.currentUser?.phoneNumber != null;

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await AnalyticsService.logLogout();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}