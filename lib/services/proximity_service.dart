// lib/services/proximity_service.dart
//
// Runs a periodic check: if the user is within alertRadius metres of a known
// hazard and hasn't been alerted for it recently, it fires a local notification.
//
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/road_hazard.dart';
import '../services/alert_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

class ProximityService {
  static const double _defaultAlertRadius = 250.0; // metres
  static const Duration _checkInterval = Duration(seconds: 8);
  static const Duration _renotifyAfter = Duration(minutes: 5);

  final LocationService _loc;
  final AlertService _alert;

  Timer? _timer;
  bool _running = false;
  double _alertRadius = _defaultAlertRadius;

  // Tracks notified hazard IDs so we don't spam, and the timers that
  // re-arm them — held so we can cancel on dispose.
  final Set<String> _notified = {};
  final Map<String, Timer> _reset = {};

  ProximityService(this._loc, this._alert) {
    _loadSettings();
  }

  bool get running => _running;
  double get alertRadius => _alertRadius;

  Future<void> _loadSettings() async {
    final p = await SharedPreferences.getInstance();
    _alertRadius = p.getDouble('alert_radius') ?? _defaultAlertRadius;
  }

  void updateAlertRadius(double metres) {
    _alertRadius = metres;
  }

  void start() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(_checkInterval, (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  Future<void> _check() async {
    final pos = _loc.current;
    if (pos == null) return;

    for (final RoadHazard hazard in _alert.nearby) {
      if (_notified.contains(hazard.id)) continue;

      final dist = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        hazard.latitude, hazard.longitude,
      );

      if (dist <= _alertRadius) {
        _notified.add(hazard.id);
        await NotificationService.showHazardAhead(hazard, dist);
        _reset[hazard.id]?.cancel();
        _reset[hazard.id] = Timer(_renotifyAfter, () {
          _notified.remove(hazard.id);
          _reset.remove(hazard.id);
        });
      }
    }
  }

  void dispose() {
    _timer?.cancel();
    for (final t in _reset.values) {
      t.cancel();
    }
    _reset.clear();
    _notified.clear();
  }
}
