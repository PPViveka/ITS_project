// lib/services/background_service.dart
//
// Keeps the accelerometer + GPS running when the app is in the background.
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/road_hazard.dart';

class BackgroundDetectionService {
  static Future<void> init() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'road_guard_bg',
        initialNotificationTitle: '🛣️ Road Guard',
        initialNotificationContent: 'Monitoring road conditions...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  static Future<bool> _onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    service.on('stop').listen((_) => service.stopSelf());
    service.on('update_notification').listen((data) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: '🛣️ Road Guard Active',
          content: data?['content'] ?? 'Monitoring...',
        );
      }
    });

    Position? lastPos;
    DateTime? lastDetected;
    const cooldown = Duration(milliseconds: 2500);
    const potholeThresh = 18.0;
    const breakerThresh = 12.0;
    final buffer = <double>[];

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) => lastPos = pos);

    accelerometerEventStream().listen((e) {
      final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      final adj = (mag - 9.81).abs();
      buffer.add(adj);
      if (buffer.length > 20) buffer.removeAt(0);

      final now = DateTime.now();
      if (lastDetected != null && now.difference(lastDetected!) < cooldown) return;
      if (lastPos == null) return;

      HazardType? type;
      if (adj >= potholeThresh) {
        type = HazardType.pothole;
      } else if (adj >= breakerThresh) {
        type = HazardType.speedBreaker;
      }

      if (type != null) {
        lastDetected = now;
        _saveOrMergeToFirestore(lastPos!, type, adj);
        service.invoke('update_notification', {
          'content': '${type.emoji} ${type.label} detected & reported!',
        });
      }
    });
  }

  /// Background-isolate-safe report path that mirrors AlertService's
  /// 50m duplicate-merge behavior so background detections don't pollute
  /// the collection with redundant docs.
  static Future<void> _saveOrMergeToFirestore(
      Position pos, HazardType type, double magnitude) async {
    try {
      if (Firebase.apps.isEmpty) return;
      final db = FirebaseFirestore.instance;
      final sev = (magnitude / 25.0).clamp(0.0, 1.0);
      const deg = 0.0005; // ~55m

      final snap = await db
          .collection('hazards')
          .where('type', isEqualTo: type.index)
          .where('latitude', isGreaterThan: pos.latitude - deg)
          .where('latitude', isLessThan: pos.latitude + deg)
          .get();

      QueryDocumentSnapshot<Map<String, dynamic>>? match;
      for (final d in snap.docs) {
        final lng = (d.data()['longitude'] as num?)?.toDouble();
        if (lng != null && (lng - pos.longitude).abs() < deg) {
          match = d;
          break;
        }
      }

      if (match != null) {
        final existingSev = (match.data()['severity'] as num?)?.toDouble() ?? 0.0;
        final existingCount = (match.data()['reportCount'] as num?)?.toInt() ?? 1;
        await match.reference.update({
          'reportCount': existingCount + 1,
          'severity': sev > existingSev ? sev : existingSev,
          'lastReported': Timestamp.now(),
        });
      } else {
        await db.collection('hazards').doc(const Uuid().v4()).set({
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'type': type.index,
          'severity': sev,
          'reportCount': 1,
          'firstReported': Timestamp.now(),
          'lastReported': Timestamp.now(),
          'source': 'background',
        });
      }
    } catch (e) {
      debugPrint('Background save failed: $e');
    }
  }

  static Future<void> start() async {
    final service = FlutterBackgroundService();
    await service.startService();
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
  }

  static Future<bool> isRunning() =>
      FlutterBackgroundService().isRunning();
}
