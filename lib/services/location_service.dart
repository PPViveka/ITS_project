// lib/services/location_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService extends ChangeNotifier {
  Position? _current;
  StreamSubscription<Position>? _sub;
  bool _tracking = false;

  Position? get current => _current;
  bool get tracking => _tracking;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
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
        debugPrint('Location error: $e');
      },
    );
  }

  Future<void> stopTracking() async {
    await _sub?.cancel();
    _sub = null;
    _tracking = false;
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
