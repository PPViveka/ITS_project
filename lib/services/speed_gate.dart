// lib/services/speed_gate.dart
//
// Wraps DetectionService — only forwards bump events when the device
// is moving above a configurable minimum speed (default 5 km/h).
// This prevents false positives when the user is parked or walking.
//
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'detection_service.dart';
import 'location_service.dart';

class SpeedGate extends ChangeNotifier {
  final DetectionService _det;
  final LocationService _loc;

  double _minSpeedKmh = 5.0;
  int _suppressed = 0;   // count of events dropped due to low speed
  int _forwarded = 0;

  int get suppressed => _suppressed;
  int get forwarded => _forwarded;

  /// Callback forwarded only when speed is sufficient
  void Function(DetectionEvent)? onConfirmed;

  SpeedGate(this._det, this._loc) {
    _loadSettings();
    _det.onDetected = _evaluate;
  }

  Future<void> _loadSettings() async {
    final p = await SharedPreferences.getInstance();
    _minSpeedKmh = p.getDouble('min_speed') ?? 5.0;
  }

  void _evaluate(DetectionEvent event) {
    final speed = _loc.current?.speed; // m/s from GPS, can be null
    if (speed == null) {
      // No GPS speed available — let it through with a warning
      _forward(event);
      return;
    }

    final speedKmh = speed * 3.6;
    if (speedKmh < _minSpeedKmh) {
      _suppressed++;
      notifyListeners();
      return; // Drop — probably parked/walking
    }
    _forward(event);
  }

  void _forward(DetectionEvent event) {
    _forwarded++;
    notifyListeners();
    onConfirmed?.call(event);
  }

  void updateMinSpeed(double kmh) {
    _minSpeedKmh = kmh;
    notifyListeners();
  }

  @override
  void dispose() {
    _det.onDetected = null;
    super.dispose();
  }
}
