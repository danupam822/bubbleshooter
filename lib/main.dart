import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/ad_service.dart';
import 'services/navigation_service.dart';
import 'services/notification_service.dart';
import 'viewmodels/game_viewmodel.dart';
import 'views/game_screen.dart';
import 'views/settings_screen.dart';
import 'login/login_screen.dart';
import 'login/login_view_model.dart';
import 'profile/profile_page.dart';

void main() {
  runZonedGuarded(() async {
    print('[Main] App starting...');
    WidgetsFlutterBinding.ensureInitialized();

    // ── Initialize Firebase ─────────────────────────────────────────
    // ─────────────────────────────────────────
    try {
      await Firebase.initializeApp();
      print('[Main] Firebase initialized');
    } catch (e) {
      print('[Main] Firebase initialization failed: $e');
    }

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // ── Initialize notification system ──────────────────────────────
    await NotificationService.init();

    // Schedule daily reminders (safe to call every launch — plugin deduplicates)
    unawaited(NotificationService.scheduleDailyReminder());   // 7:00 PM
    unawaited(NotificationService.scheduleDailyReward());     // 9:00 AM

    final gameViewModel = GameViewModel();
    // Start loading state but don't block the initial frame
    unawaited(gameViewModel.init());

    final loginViewModel = LoginViewModel();
    await loginViewModel.checkLoginStatus();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: gameViewModel),
          ChangeNotifierProvider.value(value: loginViewModel),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          // ── Global navigator key for notification-tap navigation ──
          navigatorKey: NavigationService.navigatorKey,
          // ── Named routes ─────────────────────────────────────────
          routes: {
            '/login': (context) => const LoginScreen(),
            '/game': (context) => const GameScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/profile': (context) => const ProfilePage(),
          },
          home: loginViewModel.isLoggedIn ? const GameScreen() : const LoginScreen(),
        ),
      ),
    );

    // Initialize ads after a small delay to prioritize UI
    Future.delayed(const Duration(seconds: 1), () {
      MobileAds.instance.initialize().then((_) {
        print('[Main] Ads initialized');
        AdService.loadInterstitialAd();
      });
    });
  }, (error, stack) {
    print('[Main] Error: $error');
    print(stack);
  });
}
