// lib/services/location_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService extends ChangeNotifier {
  Position? _current;
  StreamSubscription<Position>? _sub;
  bool _tracking = false;
  String _status = 'idle';

  Position? get current => _current;
  bool get tracking => _tracking;
  String get status => _status;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _status = 'Location services disabled';
      notifyListeners();
      return false;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      _status = 'Permission permanently denied';
      notifyListeners();
      return false;
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  Future<void> startTracking() async {
    if (_tracking) return;
    final granted = await requestPermission();
    if (!granted) return;

    _tracking = true;
    _status = 'tracking';
    notifyListeners();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // metres
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        _current = pos;
        notifyListeners();
      },
      onError: (e) {
        _status = 'Location error: $e';
        notifyListeners();
      },
    );
  }

  Future<void> stopTracking() async {
    await _sub?.cancel();
    _sub = null;
    _tracking = false;
    _status = 'stopped';
    notifyListeners();
  }

  /// Distance in metres between current position and a point
  double? distanceTo(double lat, double lng) {
    if (_current == null) return null;
    return Geolocator.distanceBetween(
      _current!.latitude, _current!.longitude, lat, lng,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
