// lib/services/offline_queue.dart
//
// Caches detections locally when offline and syncs to Firestore on reconnect.
// Add to pubspec.yaml:
//   shared_preferences: ^2.2.2
//   connectivity_plus: ^5.0.2
//
import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/road_hazard.dart';
import 'alert_service.dart';

class OfflineQueue {
  static const _key = 'pending_hazards';
  final AlertService _alert;
  StreamSubscription? _connSub;

  OfflineQueue(this._alert) {
    // Auto-sync when connectivity restored
    _connSub = Connectivity()
        .onConnectivityChanged
        .listen((result) {
      if (result != ConnectivityResult.none) _flush();
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
  }

  Future<void> _flush() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    if (raw.isEmpty) return;

    final failed = <String>[];
    for (final item in raw) {
      try {
        final m = jsonDecode(item) as Map<String, dynamic>;
        await _alert.reportHazard(
          lat: (m['lat'] as num).toDouble(),
          lng: (m['lng'] as num).toDouble(),
          type: HazardType.values[m['type'] as int],
          severity: (m['severity'] as num).toDouble(),
        );
      } catch (_) {
        failed.add(item); // Keep failed ones for retry
      }
    }
    await prefs.setStringList(_key, failed);
  }

  Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).length;
  }

  Future<void> forcSync() => _flush();

  void dispose() => _connSub?.cancel();
}
