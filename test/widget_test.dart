// Smoke tests for pure logic in the Road Guard app.
// Widget-level tests for the full app would require Firebase + Provider
// setup, so we keep these to pure functions and the road_hazard model.

import 'package:flutter_test/flutter_test.dart';
import 'package:speed_breaker_alert/models/road_hazard.dart';

void main() {
  group('HazardType', () {
    test('labels are non-empty', () {
      for (final t in HazardType.values) {
        expect(t.label, isNotEmpty);
        expect(t.emoji, isNotEmpty);
      }
    });
  });

  group('RoadHazard', () {
    test('toMap round-trips core fields', () {
      final now = DateTime.now();
      final h = RoadHazard(
        id: 'abc',
        latitude: 12.97,
        longitude: 77.59,
        type: HazardType.pothole,
        severity: 0.75,
        reportCount: 4,
        firstReported: now.subtract(const Duration(hours: 1)),
        lastReported: now,
      );
      final m = h.toMap();
      expect(m['latitude'], 12.97);
      expect(m['longitude'], 77.59);
      expect(m['type'], HazardType.pothole.index);
      expect(m['severity'], 0.75);
      expect(m['reportCount'], 4);
    });

    test('isNear is true within ~50m bounding box', () {
      final h = RoadHazard(
        id: 'x',
        latitude: 12.9716,
        longitude: 77.5946,
        type: HazardType.speedBreaker,
        severity: 0.4,
        reportCount: 1,
        firstReported: DateTime.now(),
        lastReported: DateTime.now(),
      );
      expect(h.isNear(12.97164, 77.59465), isTrue);
      expect(h.isNear(12.9800, 77.5946), isFalse);
    });

    test('copyWith mutates only specified fields', () {
      final h = RoadHazard(
        id: 'x',
        latitude: 0,
        longitude: 0,
        type: HazardType.roughPatch,
        severity: 0.5,
        reportCount: 1,
        firstReported: DateTime(2024),
        lastReported: DateTime(2024),
      );
      final updated = h.copyWith(reportCount: 5, severity: 0.9);
      expect(updated.reportCount, 5);
      expect(updated.severity, 0.9);
      expect(updated.id, 'x');
      expect(updated.type, HazardType.roughPatch);
    });
  });
}
