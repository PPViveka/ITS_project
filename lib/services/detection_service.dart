// lib/services/detection_service.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/road_hazard.dart';

class DetectionEvent {
  final DateTime time;
  final double magnitude;
  final HazardType type;
  DetectionEvent(this.time, this.magnitude, this.type);
}

class DetectionService extends ChangeNotifier {
  // ── Defaults (overridable via prefs / updateSensitivity) ─────────────────
  static const double _defaultSpeedBreakerThresh = 12.0;
  static const double _potholeOffset = 6.0;   // pothole = breaker + offset
  static const double _roughPatchOffset = -3.0; // rough patch = breaker - 3
  static const int _cooldownMs = 2500;
  static const int _bufferSize = 20;
  // ────────────────────────────────────────────────────────────────────────

  double _speedBreakerThresh = _defaultSpeedBreakerThresh;
  double get speedBreakerThresh => _speedBreakerThresh;

  StreamSubscription<AccelerometerEvent>? _sub;
  bool _active = false;
  DetectionEvent? _last;
  DateTime? _lastDetected;

  final List<double> _buffer = [];

  bool get active => _active;
  DetectionEvent? get lastEvent => _last;

  /// Callback invoked when a bump is confirmed
  void Function(DetectionEvent)? onDetected;

  DetectionService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final p = await SharedPreferences.getInstance();
    _speedBreakerThresh = p.getDouble('sens_thresh') ?? _defaultSpeedBreakerThresh;
  }

  void updateSensitivity(double breakerThresh) {
    _speedBreakerThresh = breakerThresh;
    notifyListeners();
  }

  void start() {
    if (_active) return;
    _active = true;
    notifyListeners();

    _sub = accelerometerEventStream().listen(_process);
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _active = false;
    _buffer.clear();
    notifyListeners();
  }

  void _process(AccelerometerEvent e) {
    final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final adjusted = (mag - 9.81).abs();
    _buffer.add(adjusted);
    if (_buffer.length > _bufferSize) _buffer.removeAt(0);

    final now = DateTime.now();
    if (_lastDetected != null &&
        now.difference(_lastDetected!).inMilliseconds < _cooldownMs) return;

    final potholeThresh = _speedBreakerThresh + _potholeOffset;
    final roughPatchThresh = _speedBreakerThresh + _roughPatchOffset;

    HazardType? detected;
    if (adjusted >= potholeThresh) {
      detected = HazardType.pothole;
    } else if (adjusted >= _speedBreakerThresh) {
      detected = HazardType.speedBreaker;
    } else if (_buffer.length == _bufferSize) {
      final mean = _buffer.reduce((a, b) => a + b) / _bufferSize;
      final variance =
          _buffer.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
          _bufferSize;
      if (mean >= roughPatchThresh - 2 && variance > 4.0) {
        detected = HazardType.roughPatch;
      }
    }

    if (detected != null) {
      _lastDetected = now;
      _last = DetectionEvent(now, adjusted, detected);
      notifyListeners();
      onDetected?.call(_last!);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
