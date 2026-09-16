import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'navigation_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Background entry points (top-level, outside any class)
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint('[Notification] Background tap: payload=${response.payload}');
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `Firebase.initializeApp()` before using other Firebase services.
  debugPrint('[Firebase] Handling background message: ${message.messageId}');
}

// ─────────────────────────────────────────────────────────────────────────────
//  Notification channel IDs
// ─────────────────────────────────────────────────────────────────────────────
const String _channelGameEvents  = 'game_events';
const String _channelReminders   = 'reminders';
const String _channelFCM         = 'fcm_notifications';

// ─────────────────────────────────────────────────────────────────────────────
//  Notification IDs
// ─────────────────────────────────────────────────────────────────────────────
const int idLevelComplete   = 1;
const int idScoreMilestone  = 2;
const int idDailyReminder   = 10;
const int idDailyReward     = 11;
const int idFCMBase         = 100;

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static bool _initialized = false;

  // ── Android notification channels ─────────────────────────────────────────
  static const AndroidNotificationChannel _gameEventsChannel =
      AndroidNotificationChannel(
    _channelGameEvents,
    'Game Events',
    description: 'Level completions, score milestones, in-game alerts.',
    importance: Importance.high,
    playSound: true,
  );

  static const AndroidNotificationChannel _remindersChannel =
      AndroidNotificationChannel(
    _channelReminders,
    'Reminders',
    description: 'Daily comeback reminders and reward alerts.',
    importance: Importance.defaultImportance,
    playSound: true,
  );

  static const AndroidNotificationChannel _fcmChannel =
      AndroidNotificationChannel(
    _channelFCM,
    'Push Notifications',
    description: 'Important updates and news via push.',
    importance: Importance.max,
    playSound: true,
  );

  // ── Init ──────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    if (_initialized) return;

    // 1. Timezone database
    tz_data.initializeTimeZones();
    try {
      final localTz = DateTime.now().timeZoneName;
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); // fallback
    }

    // 2. Local Notifications init
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // 3. Create channels on Android
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_gameEventsChannel);
    await androidPlugin?.createNotificationChannel(_remindersChannel);
    await androidPlugin?.createNotificationChannel(_fcmChannel);

    // 4. Request permissions
    await _requestPermission();

    // 5. Setup Firebase Messaging
    await _initFCM();

    _initialized = true;
    debugPrint('[NotificationService] Initialized.');
  }

  // ── Firebase Messaging Setup ──────────────────────────────────────────────
  static Future<void> _initFCM() async {
    // Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[Firebase] Message received in foreground: ${message.notification?.title}');
      if (message.notification != null) {
        showNow(
          id: idFCMBase + message.hashCode,
          title: message.notification!.title ?? 'New Message',
          body: message.notification!.body ?? '',
          channel: _channelFCM,
          payload: message.data['screen'] ?? 'game_screen',
        );
      }
    });

    // When app is opened via notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[Firebase] Message opened app: ${message.data}');
      _handlePayload(message.data['screen']);
    });

    // Check for initial message (when app is launched from terminated state)
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[Firebase] Initial message found: ${initialMessage.data}');
      _handlePayload(initialMessage.data['screen']);
    }

    // Get FCM Token
    String? token = await _fcm.getToken();
    debugPrint('[Firebase] FCM Token: $token');

    // Get Installation ID (for In-App Messaging testing)
    try {
      String id = await FirebaseInstallations.instance.getId();
      debugPrint('[Firebase] Installation ID (FID): $id');
      debugPrint('[Firebase] Use this ID in Firebase Console to "Test on device" for In-App Messaging');
    } catch (e) {
      debugPrint('[Firebase] Could not get Installation ID: $e');
    }
  }

  // ── Permission request ────────────────────────────────────────────────────
  static Future<void> _requestPermission() async {
    // FCM Permissions (iOS)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('[NotificationService] FCM permission status: ${settings.authorizationStatus}');

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      debugPrint('[NotificationService] Local notification permission granted: $granted');
    }
  }

  // ── Foreground notification tap handler ───────────────────────────────────
  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('[NotificationService] Tapped: payload=${response.payload}');
    _handlePayload(response.payload);
  }

  static void _handlePayload(String? payload) {
    if (payload == null) return;
    // Route based on payload
    switch (payload) {
      case 'game_screen':
        NavigationService.navigateTo('/game');
        break;
      default:
        NavigationService.navigateTo('/game');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PUBLIC API
  // ─────────────────────────────────────────────────────────────────────────

  /// Show an immediate notification (foreground / background).
  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String channel = _channelGameEvents,
    String payload = 'game_screen',
    String? bigText,
  }) async {
    if (!_initialized) return;
    final androidDetails = AndroidNotificationDetails(
      channel,
      channel == _channelGameEvents ? 'Game Events' : (channel == _channelFCM ? 'Push Notifications' : 'Reminders'),
      channelDescription: 'Bubble Blast notifications',
      importance: channel == _channelGameEvents || channel == _channelFCM
          ? Importance.max
          : Importance.defaultImportance,
      priority: Priority.high,
      styleInformation: bigText != null
          ? BigTextStyleInformation(bigText)
          : null,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// Schedule a daily repeating notification at [hour]:[minute] local time.
  static Future<void> scheduleDailyAt({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String payload = 'game_screen',
  }) async {
    if (!_initialized) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    // If that time is already past today, schedule for tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      _channelReminders,
      'Reminders',
      channelDescription: 'Daily Bubble Blast reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily
    );
    debugPrint('[NotificationService] Scheduled daily at $hour:$minute (id=$id)');
  }

  /// Cancel a single notification by ID.
  static Future<void> cancel(int id) => _plugin.cancel(id);

  /// Cancel all scheduled and shown notifications.
  static Future<void> cancelAll() => _plugin.cancelAll();

  /// Check what notification (if any) launched the app from terminated state.
  static Future<String?> getInitialPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }

  // ── Firebase In-App Messaging ─────────────────────────────────────────────

  /// Trigger a custom event for In-App Messaging.
  static Future<void> triggerInAppMessage(String eventName) async {
    await FirebaseInAppMessaging.instance.triggerEvent(eventName);
    debugPrint('[FIAM] Triggered event: $eventName');
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  GAME-SPECIFIC HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> notifyLevelComplete(int level, int bonus) => showNow(
        id: idLevelComplete,
        title: '🎉 Level $level Complete!',
        body: 'You earned +$bonus bonus points. Keep it up!',
        bigText: 'Amazing! You cleared Level $level and earned +$bonus bonus points.\nCan you beat the next one?',
      );

  static Future<void> notifyScoreMilestone(int score) => showNow(
        id: idScoreMilestone,
        title: '🏆 Score Milestone: $score!',
        body: 'You\'re on fire! Keep popping those bubbles! 🫧',
      );

  static Future<void> scheduleDailyReminder() => scheduleDailyAt(
        id: idDailyReminder,
        hour: 19, // 7:00 PM
        minute: 0,
        title: '🫧 Your bubbles miss you!',
        body: 'Come back and pop some bubbles. A new challenge awaits!',
      );

  static Future<void> scheduleDailyReward() => scheduleDailyAt(
        id: idDailyReward,
        hour: 9, // 9:00 AM
        minute: 0,
        title: '🎁 Daily Reward Ready!',
        body: 'Your daily bonus is waiting. Open Bubble Blast now!',
      );
}
