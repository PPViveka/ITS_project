// lib/services/notification_service.dart
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/road_hazard.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int _detectionCounter = 0;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  static int _safeId(int raw) => raw & 0x7FFFFFFF;

  static Future<({bool vibrate, bool sound})> _readPrefs() async {
    final p = await SharedPreferences.getInstance();
    return (
      vibrate: p.getBool('vibrate') ?? true,
      sound: p.getBool('sound') ?? true,
    );
  }

  static Future<void> showHazardAhead(RoadHazard hazard, double distanceM) async {
    final dist = distanceM < 1000
        ? '${distanceM.toStringAsFixed(0)} m'
        : '${(distanceM / 1000).toStringAsFixed(1)} km';
    final prefs = await _readPrefs();

    await _plugin.show(
      _safeId(hazard.id.hashCode),
      '${hazard.type.emoji} ${hazard.type.label} Ahead!',
      '$dist away • reported ${hazard.reportCount}× • slow down',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'hazard_channel',
          'Hazard Alerts',
          channelDescription: 'Road hazard proximity alerts',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFFFF6B2B),
          enableVibration: prefs.vibrate,
          playSound: prefs.sound,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: prefs.sound,
        ),
      ),
    );
  }

  static Future<void> showDetected(RoadHazard hazard) async {
    final prefs = await _readPrefs();
    _detectionCounter = (_detectionCounter + 1) & 0x7FFFFFFF;
    await _plugin.show(
      _detectionCounter,
      '${hazard.type.emoji} ${hazard.type.label} Detected & Reported',
      'Magnitude: ${hazard.severity.toStringAsFixed(1)} • Location saved',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'detection_channel',
          'Detection Alerts',
          channelDescription: 'Bump/pothole auto-detection',
          importance: Importance.defaultImportance,
          enableVibration: prefs.vibrate,
          playSound: prefs.sound,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: prefs.sound,
        ),
      ),
    );
  }
}
