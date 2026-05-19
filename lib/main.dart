// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/alert_service.dart';
import 'services/background_service.dart';
import 'services/detection_service.dart';
import 'services/location_service.dart';
import 'services/offline_queue.dart';
import 'services/speed_gate.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // Anonymous sign-in so Firestore rules requiring request.auth != null pass.
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    await BackgroundDetectionService.init();
  } catch (e) {
    debugPrint('Firebase / background init failed: $e');
  }
  runApp(const SpeedBreakerApp());
}

class SpeedBreakerApp extends StatelessWidget {
  const SpeedBreakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => DetectionService()),
        ChangeNotifierProvider(create: (_) {
          final queue = OfflineQueue();
          final alert = AlertService()..offlineQueue = queue;
          return alert;
        }),
        // SpeedGate depends on DetectionService + LocationService.
        ChangeNotifierProxyProvider2<DetectionService, LocationService, SpeedGate>(
          create: (ctx) => SpeedGate(
            ctx.read<DetectionService>(),
            ctx.read<LocationService>(),
          ),
          update: (_, __, ___, prev) => prev!,
        ),
      ],
      child: MaterialApp(
        title: 'Road Guard',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        initialRoute: '/',
        routes: {
          '/': (_) => const SplashScreen(),
          '/home': (_) => const HomeScreen(),
        },
      ),
    );
  }
}

class AppTheme {
  static const _bg = Color(0xFF0A0E1A);
  static const _surface = Color(0xFF121829);
  static const _card = Color(0xFF1C2438);
  static const _accent = Color(0xFFFF6B2B);
  static const _accentGlow = Color(0xFFFF8C55);
  static const _safe = Color(0xFF2ECC71);
  static const _warning = Color(0xFFF39C12);
  static const _danger = Color(0xFFE74C3C);
  static const _textPrimary = Color(0xFFECF0F1);
  static const _textSecondary = Color(0xFF8899AA);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        primaryColor: _accent,
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          secondary: _accentGlow,
          surface: _surface,
          error: _danger,
        ),
        cardColor: _card,
        extensions: [const AppColors(
          bg: _bg,
          surface: _surface,
          card: _card,
          accent: _accent,
          accentGlow: _accentGlow,
          safe: _safe,
          warning: _warning,
          danger: _danger,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
        )],
        fontFamily: 'monospace',
        appBarTheme: const AppBarTheme(
          backgroundColor: _surface,
          foregroundColor: _textPrimary,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: _textPrimary),
          bodySmall: TextStyle(color: _textSecondary),
        ),
      );
}
