// lib/services/detection_service.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/road_hazard.dart';

class DetectionEvent {
  final DateTime time;
  final double magnitude;
  final HazardType type;
  DetectionEvent(this.time, this.magnitude, this.type);
}

class DetectionService extends ChangeNotifier {
  // ── Tunable thresholds ───────────────────────────────────────────────────
  static const double _potholeThreshold    = 18.0; // m/s²  sharp spike
  static const double _speedBreakerThresh  = 12.0; // m/s²  sustained rise
  static const double _roughPatchThresh    =  9.0; // m/s²  repeated mild bumps
  static const int    _cooldownMs          = 2500;  // ms between events
  // ────────────────────────────────────────────────────────────────────────

  StreamSubscription<AccelerometerEvent>? _sub;
  bool _active = false;
  DetectionEvent? _last;
  DateTime? _lastDetected;

  // Circular buffer for roughness detection
  final List<double> _buffer = [];
  static const int _bufferSize = 20;

  bool get active => _active;
  DetectionEvent? get lastEvent => _last;

  /// Callback invoked when a bump is confirmed
  void Function(DetectionEvent)? onDetected;

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
    // Vector magnitude of all 3 axes
    final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);

    // Maintain rolling buffer (remove gravity baseline ~9.8)
    final adjusted = (mag - 9.81).abs();
    _buffer.add(adjusted);
    if (_buffer.length > _bufferSize) _buffer.removeAt(0);

    // Cooldown guard
    final now = DateTime.now();
    if (_lastDetected != null &&
        now.difference(_lastDetected!).inMilliseconds < _cooldownMs) return;

    HazardType? detected;

    if (adjusted >= _potholeThreshold) {
      detected = HazardType.pothole;
    } else if (adjusted >= _speedBreakerThresh) {
      detected = HazardType.speedBreaker;
    } else if (_buffer.length == _bufferSize) {
      // Rough patch: check variance over the buffer
      final mean = _buffer.reduce((a, b) => a + b) / _bufferSize;
      final variance =
          _buffer.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
          _bufferSize;
      if (mean >= _roughPatchThresh - 2 && variance > 4.0) {
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
