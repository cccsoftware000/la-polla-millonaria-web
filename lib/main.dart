import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:la_polla_millonaria/services/analytics_service.dart';

import '../../core/theme/app_colors.dart';

import 'screens/splash/splash_screen.dart';

import 'firebase_options.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(

    options:
    DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Inicializar Analytics (lo activa o desactiva según Firestore)
  //await AnalyticsService.initialize();

  FlutterError.onError =
      FirebaseCrashlytics.instance
          .recordFlutterFatalError;

  PlatformDispatcher.instance.onError =
      (error, stack) {

    FirebaseCrashlytics.instance
        .recordError(
      error,
      stack,
      fatal: true,
    );

    return true;
  };

  runApp(
    const MyApp(),
  );
}

class MyApp extends StatelessWidget {

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MaterialApp(

      debugShowCheckedModeBanner: false,

      title: 'La Polla Millonaria',

      theme: ThemeData(

        scaffoldBackgroundColor:
        AppColors.background,

        fontFamily: 'Roboto',
      ),

      home: const SplashScreen(),
    );
  }
}