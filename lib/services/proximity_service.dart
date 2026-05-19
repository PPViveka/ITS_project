// lib/services/proximity_service.dart
//
// Runs a periodic check: if the user is within ALERT_RADIUS metres of a known
// hazard and hasn't been alerted for it recently, it fires a local notification.
//
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/road_hazard.dart';
import '../services/alert_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

class ProximityService extends ChangeNotifier {
  static const double alertRadius = 250.0; // metres
  static const Duration _checkInterval = Duration(seconds: 8);

  final LocationService _loc;
  final AlertService _alert;

  Timer? _timer;
  bool _running = false;

  // Tracks which hazard IDs we've already notified so we don't spam
  final Set<String> _notified = {};

  ProximityService(this._loc, this._alert);

  bool get running => _running;

  void start() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(_checkInterval, (_) => _check());
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    notifyListeners();
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

      if (dist <= alertRadius) {
        _notified.add(hazard.id);
        await NotificationService.showHazardAhead(hazard, dist);
        // Remove from notified set after 5 min so it can fire again
        Future.delayed(const Duration(minutes: 5), () {
          _notified.remove(hazard.id);
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
