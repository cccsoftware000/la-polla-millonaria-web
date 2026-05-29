import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsService {
  static final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  static bool _isEnabled = false;
  static bool _initialized = false;

  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  // ✅ Inicializar desde Firestore
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Opción 1: Desde Firestore (configurable en tiempo real)
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('analytics')
          .get();

      if (doc.exists) {
        _isEnabled = doc.data()?['enabled'] ?? false;
      } else {
        // Opción 2: Desde SharedPreferences (local)
        final prefs = await SharedPreferences.getInstance();
        _isEnabled = prefs.getBool('analytics_enabled') ?? false;
      }
    } catch (e) {
      print('Error initializing analytics: $e');
      _isEnabled = false;
    }

    _initialized = true;
    print('📊 Analytics enabled: $_isEnabled');
  }

  // ✅ Activar/desactivar remotamente desde Firestore
  static Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;

    // Guardar en Firestore
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('analytics')
          .set({'enabled': enabled, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Error saving analytics setting: $e');
    }

    // Guardar localmente
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('analytics_enabled', enabled);

    print('📊 Analytics set to: $enabled');
  }

  // ✅ Verificar si está activo
  static bool get isEnabled => _isEnabled && _initialized;

  // ✅ Método seguro que solo ejecuta si está habilitado
  static Future<void> _safeLogEvent(
      String eventName, {
        Map<String, Object>? parameters,
      }) async {
    if (!_isEnabled) return; // 👈 NO hacer nada si está desactivado

    try {
      await analytics.logEvent(name: eventName, parameters: parameters);
    } catch (e) {
      print('Error logging event $eventName: $e');
    }
  }

  static FirebaseAnalyticsObserver getObserver() {
    return FirebaseAnalyticsObserver(analytics: analytics);
  }

  // ==================== SCREEN TRACKING ====================

  static Future<void> logScreen({
    required String screenName,
    String? screenClass,
  }) async {
    if (!_isEnabled) return;

    try {
      await analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e) {
      print('Error logging screen: $e');
    }
  }

  // ==================== AUTHENTICATION EVENTS ====================

  static Future<void> logLogin({String? phoneNumber}) async {
    if (!_isEnabled) return;

    try {
      await analytics.logLogin(loginMethod: 'phone');
      await _safeLogEvent('login_success', parameters: {
        'phone': phoneNumber?.substring(phoneNumber.length - 4) ?? 'unknown',
      });
    } catch (e) {
      print('Error logging login: $e');
    }
  }

  static Future<void> logLoginError({required String error}) async {
    if (!_isEnabled) return;
    await _safeLogEvent('login_error', parameters: {'error': error});
  }

  static Future<void> logRegister({String? phoneNumber}) async {
    if (!_isEnabled) return;

    try {
      await analytics.logSignUp(signUpMethod: 'phone');
      await _safeLogEvent('register_success', parameters: {
        'phone': phoneNumber?.substring(phoneNumber.length - 4) ?? 'unknown',
      });
    } catch (e) {
      print('Error logging register: $e');
    }
  }

  static Future<void> logRegisterError({required String error}) async {
    if (!_isEnabled) return;
    await _safeLogEvent('register_error', parameters: {'error': error});
  }

  static Future<void> logLogout() async {
    if (!_isEnabled) return;
    await _safeLogEvent('logout');
  }

  // ==================== BET EVENTS ====================

  static Future<void> logBetCreated({int? predictionsCount}) async {
    if (!_isEnabled) return;
    await _safeLogEvent('bet_created', parameters: {
      'predictions_count': predictionsCount ?? 8,
    });
  }

  static Future<void> logBetUpdated({required String betId}) async {
    if (!_isEnabled) return;
    await _safeLogEvent('bet_updated', parameters: {'bet_id': betId});
  }

  static Future<void> logBetDeleted({required String betId}) async {
    if (!_isEnabled) return;
    await _safeLogEvent('bet_deleted', parameters: {'bet_id': betId});
  }

  static Future<void> logBetConfirmed({required String betId}) async {
    if (!_isEnabled) return;
    await _safeLogEvent('bet_confirmed', parameters: {'bet_id': betId});
  }

  static Future<void> logBetPaid({required String betId}) async {
    if (!_isEnabled) return;
    await _safeLogEvent('bet_paid', parameters: {'bet_id': betId});
  }

  static Future<void> logBetCancelled({required String betId}) async {
    if (!_isEnabled) return;
    await _safeLogEvent('bet_cancelled', parameters: {'bet_id': betId});
  }

  static Future<void> logBetEdited({required String betId}) async {
    if (!_isEnabled) return;
    await _safeLogEvent('bet_edited', parameters: {'bet_id': betId});
  }

  // ==================== PROFILE EVENTS ====================

  static Future<void> logProfileCompleted() async {
    if (!_isEnabled) return;
    await _safeLogEvent('profile_completed');
  }

  static Future<void> logProfileUpdated() async {
    if (!_isEnabled) return;
    await _safeLogEvent('profile_updated');
  }

  static Future<void> logAvatarChanged() async {
    if (!_isEnabled) return;
    await _safeLogEvent('avatar_changed');
  }

  // ==================== ONBOARDING EVENTS ====================

  static Future<void> logOnboardingStarted() async {
    if (!_isEnabled) return;
    await _safeLogEvent('onboarding_started');
  }

  static Future<void> logOnboardingCompleted() async {
    if (!_isEnabled) return;
    await _safeLogEvent('onboarding_completed');
  }

  static Future<void> logOnboardingSkipped() async {
    if (!_isEnabled) return;
    await _safeLogEvent('onboarding_skipped');
  }

  // ==================== ERROR TRACKING ====================

  static Future<void> logError({
    required String error,
    required String source,
    Map<String, Object>? additionalParams,
  }) async {
    if (!_isEnabled) return;

    final Map<String, Object> params = {
      'error': error,
      'source': source,
    };
    if (additionalParams != null) params.addAll(additionalParams);
    await _safeLogEvent('app_error', parameters: params);
  }

  // ==================== PAYMENT EVENTS ====================

  static Future<void> logPaymentInitiated({required double amount}) async {
    if (!_isEnabled) return;
    await _safeLogEvent('payment_initiated', parameters: {'amount': amount});
  }

  static Future<void> logPaymentSuccess({required double amount}) async {
    if (!_isEnabled) return;
    await _safeLogEvent('payment_success', parameters: {'amount': amount});
  }

  static Future<void> logPaymentError({required String error}) async {
    if (!_isEnabled) return;
    await _safeLogEvent('payment_error', parameters: {'error': error});
  }

  // ==================== NOTIFICATION EVENTS ====================

  static Future<void> logNotificationReceived({required String type}) async {
    if (!_isEnabled) return;
    await _safeLogEvent('notification_received', parameters: {'type': type});
  }

  static Future<void> logNotificationOpened({required String type}) async {
    if (!_isEnabled) return;
    await _safeLogEvent('notification_opened', parameters: {'type': type});
  }

  // ==================== SHARE EVENTS ====================

  static Future<void> logShareApp() async {
    if (!_isEnabled) return;
    await _safeLogEvent('share_app');
  }

  static Future<void> logShareResult({required String platform}) async {
    if (!_isEnabled) return;
    await _safeLogEvent('share_result', parameters: {'platform': platform});
  }

  // ==================== SESSION TIMING ====================

  static Future<void> logSessionStart() async {
    if (!_isEnabled) return;
    await _safeLogEvent('session_start');
  }

  static Future<void> logSessionEnd({required int durationSeconds}) async {
    if (!_isEnabled) return;
    await _safeLogEvent('session_end', parameters: {'duration_seconds': durationSeconds});
  }

  // ==================== HELPER METHODS ====================

  static Future<void> setUserId(String? userId) async {
    if (!_isEnabled) return;

    try {
      if (userId != null) {
        await analytics.setUserId(id: userId);
      }
    } catch (e) {
      print('Error setting user id: $e');
    }
  }

  static Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    if (!_isEnabled) return;

    try {
      await analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      print('Error setting user property: $e');
    }
  }

  static Future<void> setUserPremiumStatus(bool isPremium) async {
    if (!_isEnabled) return;
    await setUserProperty(name: 'is_premium', value: isPremium.toString());
  }

  static Future<void> resetAnalytics() async {
    if (!_isEnabled) return;

    try {
      await analytics.setUserId(id: null);
      await _safeLogEvent('analytics_reset');
    } catch (e) {
      print('Error resetting analytics: $e');
    }
  }
}

// Extensión para facilitar el uso en widgets
extension AnalyticsExtension on Widget {
  Widget withAnalytics(String screenName) {
    return ScreenAnalyticsTracker(
      screenName: screenName,
      child: this,
    );
  }
}

class ScreenAnalyticsTracker extends StatefulWidget {
  final String screenName;
  final Widget child;

  const ScreenAnalyticsTracker({
    super.key,
    required this.screenName,
    required this.child,
  });

  @override
  State<ScreenAnalyticsTracker> createState() => _ScreenAnalyticsTrackerState();
}

class _ScreenAnalyticsTrackerState extends State<ScreenAnalyticsTracker> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreen(screenName: widget.screenName);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}