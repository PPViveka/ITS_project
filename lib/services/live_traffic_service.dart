import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LiveVehicle {
  final String uid;
  final double lat;
  final double lng;
  final double speed;   // m/s
  final double heading; // degrees
  final DateTime ts;

  const LiveVehicle({
    required this.uid,
    required this.lat,
    required this.lng,
    required this.speed,
    required this.heading,
    required this.ts,
  });
}

class LiveTrafficService extends ChangeNotifier {
  static const _staleLimitMs = 30000; // 30 seconds

  FirebaseDatabase? get _rtdb {
    try {
      return FirebaseDatabase.instance;
    } catch (_) {
      return null;
    }
  }

  StreamSubscription<Position>? _posSub;
  StreamSubscription<DatabaseEvent>? _readSub;

  List<LiveVehicle> _vehicles = [];
  List<LiveVehicle> get vehicles => List.unmodifiable(_vehicles);

  String? get _myUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  // ── Start broadcasting this device's position ───────────────────────────
  void startBroadcasting(Stream<Position> positionStream) {
    final uid = _myUid;
    final db = _rtdb;
    if (uid == null || db == null) return;

    final ref = db.ref('live/$uid');
    ref.onDisconnect().remove();

    _posSub = positionStream.listen((pos) {
      ref.set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'speed': pos.speed,
        'heading': pos.heading,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  // ── Listen to all active vehicles ───────────────────────────────────────
  void startListening() {
    final db = _rtdb;
    if (db == null) return;

    _readSub = db.ref('live').onValue.listen((event) {
      final raw = event.snapshot.value;
      if (raw == null) {
        _vehicles = [];
        notifyListeners();
        return;
      }

      final map = Map<String, dynamic>.from(raw as Map);
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final myUid = _myUid;

      _vehicles = map.entries
          .where((e) {
            if (e.key == myUid) return false; // don't show self
            final m = Map<String, dynamic>.from(e.value as Map);
            final ts = (m['ts'] as num?)?.toInt() ?? 0;
            return nowMs - ts < _staleLimitMs;
          })
          .map((e) {
            final m = Map<String, dynamic>.from(e.value as Map);
            return LiveVehicle(
              uid: e.key,
              lat: (m['lat'] as num).toDouble(),
              lng: (m['lng'] as num).toDouble(),
              speed: (m['speed'] as num?)?.toDouble() ?? 0.0,
              heading: (m['heading'] as num?)?.toDouble() ?? 0.0,
              ts: DateTime.fromMillisecondsSinceEpoch(
                  (m['ts'] as num).toInt()),
            );
          })
          .toList();

      notifyListeners();
    }, onError: (e) {
      debugPrint('LiveTrafficService read error: $e');
    });
  }

  void stop() {
    _posSub?.cancel();
    _readSub?.cancel();
    final uid = _myUid;
    final db = _rtdb;
    if (uid != null && db != null) {
      db.ref('live/$uid').remove();
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
