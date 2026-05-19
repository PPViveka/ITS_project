// lib/services/offline_queue.dart
//
// Caches detections locally when offline and syncs to Firestore on reconnect.
//
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/road_hazard.dart';

class OfflineQueue {
  static const _key = 'pending_hazards';
  StreamSubscription? _connSub;

  OfflineQueue() {
    _connSub = Connectivity()
        .onConnectivityChanged
        .listen((result) {
      if (result != ConnectivityResult.none) flush();
    });
  }

  Future<void> enqueue({
    required double lat,
    required double lng,
    required HazardType type,
    required double severity,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(jsonEncode({
      'lat': lat,
      'lng': lng,
      'type': type.index,
      'severity': severity,
      'ts': DateTime.now().toIso8601String(),
    }));
    await prefs.setStringList(_key, raw);
    debugPrint('OfflineQueue: enqueued (total ${raw.length})');
  }

  /// Flushes queued items by writing them directly to Firestore.
  /// Items that fail are kept for the next retry.
  Future<void> flush() async {
    if (Firebase.apps.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    if (raw.isEmpty) return;

    final db = FirebaseFirestore.instance;
    final failed = <String>[];
    for (final item in raw) {
      try {
        final m = jsonDecode(item) as Map<String, dynamic>;
        final ts = DateTime.tryParse(m['ts'] as String? ?? '') ?? DateTime.now();
        await db.collection('hazards').doc(const Uuid().v4()).set({
          'latitude': (m['lat'] as num).toDouble(),
          'longitude': (m['lng'] as num).toDouble(),
          'type': m['type'] as int,
          'severity': (m['severity'] as num).toDouble(),
          'reportCount': 1,
          'firstReported': Timestamp.fromDate(ts),
          'lastReported': Timestamp.fromDate(ts),
          'source': 'offline-queue',
        });
      } catch (e) {
        debugPrint('OfflineQueue flush: keeping item for retry ($e)');
        failed.add(item);
      }
    }
    await prefs.setStringList(_key, failed);
  }

  Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).length;
  }

  Future<void> forceSync() => flush();

  void dispose() => _connSub?.cancel();
}
