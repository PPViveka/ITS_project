import 'dart:convert';
import 'dart:math' as dart_math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/road_hazard.dart';

class RouteOption {
  final List<LatLng> points;
  final double distance; // meters
  final double duration; // seconds
  final List<RoadHazard> hazards;
  final double safetyScore; // 0-100, higher is better

  RouteOption({
    required this.points,
    required this.distance,
    required this.duration,
    required this.hazards,
    required this.safetyScore,
  });
}

class RoutingService {
  static const _baseUrl = 'https://router.project-osrm.org/route/v1/driving';
  static const _hazardProximityMeters = 30.0;

  /// Fetches multiple alternative routes from OSRM and calculates a safety score
  /// based on the number of intersecting hazards.
  static Future<List<RouteOption>> fetchSafeRoutes(
    LatLng origin,
    LatLng destination,
    List<RoadHazard> allHazards,
  ) async {
    final url =
        '$_baseUrl/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}?geometries=geojson&overview=full&alternatives=true';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      if (data['code'] != 'Ok') return [];

      final routes = data['routes'] as List;
      final options = <RouteOption>[];

      for (final r in routes) {
        final geom = r['geometry'];
        final coords = geom['coordinates'] as List;
        final points = <LatLng>[];
        for (final c in coords) {
          final lng = (c[0] as num).toDouble();
          final lat = (c[1] as num).toDouble();
          points.add(LatLng(lat, lng));
        }

        final dist = (r['distance'] as num).toDouble();
        final dur = (r['duration'] as num).toDouble();

        // Find intersecting hazards (within proximity radius of any route point).
        final intersecting = <RoadHazard>{};
        for (final p in points) {
          for (final h in allHazards) {
            if (_distanceBetween(p.latitude, p.longitude, h.latitude, h.longitude) < _hazardProximityMeters) {
              intersecting.add(h);
            }
          }
        }

        // Calculate safety score (start at 100, deduct based on hazards and severity)
        double penalty = 0;
        for (final h in intersecting) {
          penalty += 5 + (h.severity * 10);
        }
        final safety = (100 - penalty).clamp(10.0, 100.0);

        options.add(RouteOption(
          points: points,
          distance: dist,
          duration: dur,
          hazards: intersecting.toList(),
          safetyScore: safety,
        ));
      }

      // Sort by safety score descending
      options.sort((a, b) => b.safetyScore.compareTo(a.safetyScore));

      return options;
    } catch (e) {
      debugPrint('Routing error: $e');
      return [];
    }
  }

  /// Haversine formula for distance in meters
  static double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295; // Math.PI / 180
    var a = 0.5 -
        dart_math.cos((lat2 - lat1) * p) / 2 +
        dart_math.cos(lat1 * p) * dart_math.cos(lat2 * p) * (1 - dart_math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * 1000 * dart_math.asin(dart_math.sqrt(a));
  }
}
