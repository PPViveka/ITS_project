// lib/services/background_service.dart
//
// Keeps the accelerometer + GPS running when the app is in the background.
// Uses flutter_background_service (add to pubspec.yaml):
//   flutter_background_service: ^5.0.5
//
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

    // Location stream
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) => lastPos = pos);

    // Accelerometer stream
    accelerometerEventStream().listen((e) {
      final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      final adj = (mag - 9.81).abs();
      buffer.add(adj);
      if (buffer.length > 20) buffer.removeAt(0);

      final now = DateTime.now();
      if (lastDetected != null && now.difference(lastDetected!) < cooldown) return;
      if (lastPos == null) return;

      HazardType? type;
      if (adj >= potholeThresh) type = HazardType.pothole;
      else if (adj >= breakerThresh) type = HazardType.speedBreaker;

      if (type != null) {
        lastDetected = now;
        _saveToFirestore(lastPos!, type, adj);
        service.invoke('update_notification', {
          'content': '${type.emoji} ${type.label} detected & reported!',
        });
      }
    });
  }

  static Future<void> _saveToFirestore(
      Position pos, HazardType type, double magnitude) async {
    try {
      if (Firebase.apps.isEmpty) return;
      final db = FirebaseFirestore.instance;
      final sev = (magnitude / 25.0).clamp(0.0, 1.0);
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
    } catch (_) {}
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
