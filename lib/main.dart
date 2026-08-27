import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/ad_service.dart';
import 'viewmodels/game_viewmodel.dart';
import 'views/game_screen.dart';

void main() {
  runZonedGuarded(() async {
    print('[Main] App starting...');
    WidgetsFlutterBinding.ensureInitialized();
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    final gameViewModel = GameViewModel();
    // Start loading state but don't block the initial frame
    unawaited(gameViewModel.init());

    runApp(
      ChangeNotifierProvider.value(
        value: gameViewModel,
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: GameScreen(),
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
