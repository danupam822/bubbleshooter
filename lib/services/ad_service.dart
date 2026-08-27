import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static InterstitialAd? _interstitialAd;
  static bool _isAdLoaded = false;

  // Demo Interstitial Ad ID for Android
  static const String _adUnitId = 'ca-app-pub-3940256099942544/1033173712';

  static Future<void> loadInterstitialAd() async {
    final List<ConnectivityResult> connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.isEmpty || connectivityResult.contains(ConnectivityResult.none)) {
      print('AdService: No network, skipping load.');
      return;
    }

    print('AdService: Loading Interstitial Ad...');
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          print('AdService: Ad Loaded Successfully');
          _interstitialAd = ad;
          _isAdLoaded = true;
          
          _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              print('AdService: Ad showed.');
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
            },
            onAdDismissedFullScreenContent: (ad) {
              print('AdService: Ad dismissed.');
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
              ad.dispose();
              _isAdLoaded = false;
              loadInterstitialAd(); // Preload for next time
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('AdService: Ad failed to show: $error');
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
              ad.dispose();
              _isAdLoaded = false;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('AdService: Ad failed to load: $error');
          _isAdLoaded = false;
        },
      ),
    );
  }

  static Future<void> showInterstitialAdWithFallback(BuildContext context) async {
    // For testing/debugging, we can force the Mock Ad to ensure the "X" button is seen.
    // Set forceMock to false if you want to prefer real Google Ads.
    const bool forceMock = true; 

    final List<ConnectivityResult> connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.isEmpty || connectivityResult.contains(ConnectivityResult.none)) {
      print('AdService: No network, skipping ad.');
      return;
    }

    if (!forceMock && _isAdLoaded && _interstitialAd != null) {
      print('AdService: Showing Google Interstitial Ad.');
      await _interstitialAd!.show();
    } else {
      print('AdService: Showing Mock Ad (Timer based).');
      _showMockAd(context);
      if (!forceMock) loadInterstitialAd();
    }
  }

  static void _showMockAd(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (context) => const _MockAdOverlay(),
    );
  }
}

class _MockAdOverlay extends StatefulWidget {
  const _MockAdOverlay();

  @override
  State<_MockAdOverlay> createState() => _MockAdOverlayState();
}

class _MockAdOverlayState extends State<_MockAdOverlay> {
  int _secondsRemaining = 10;
  Timer? _timer;
  bool _canClose = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _canClose = true;
          _timer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          // 1. "Ad" Content Background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blueGrey.shade900, Colors.black],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.featured_video_rounded, size: 100, color: Colors.blueAccent),
                const SizedBox(height: 30),
                const Text(
                  'SPONSORED AD',
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 28, 
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'This is a demo advertisement.\nYour game will resume shortly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(color: Colors.blueAccent),
              ],
            ),
          ),

          // 2. The Close/Timer Button Area (Top Right)
          Positioned(
            top: topPadding > 0 ? topPadding : 40,
            right: 20,
            child: _canClose
                ? GestureDetector(
                    onTap: () {
                      print('AdService: Manual close tapped.');
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)
                        ],
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 36),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Close in ',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$_secondsRemaining',
                          style: const TextStyle(
                            color: Colors.yellowAccent, 
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          
          // 3. Bottom Label
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'ADVERTISEMENT',
                style: TextStyle(color: Colors.white24, letterSpacing: 5, fontSize: 12),
              ),
            ),
          )
        ],
      ),
    );
  }
}
