// lib/services/notification_service.dart
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/road_hazard.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

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

  static Future<void> showHazardAhead(RoadHazard hazard, double distanceM) async {
    final dist = distanceM < 1000
        ? '${distanceM.toStringAsFixed(0)} m'
        : '${(distanceM / 1000).toStringAsFixed(1)} km';

    await _plugin.show(
      hazard.hashCode,
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
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }

  static Future<void> showDetected(RoadHazard hazard) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '${hazard.type.emoji} ${hazard.type.label} Detected & Reported',
      'Magnitude: ${hazard.severity.toStringAsFixed(1)} • Location saved',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'detection_channel',
          'Detection Alerts',
          channelDescription: 'Bump/pothole auto-detection',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}

