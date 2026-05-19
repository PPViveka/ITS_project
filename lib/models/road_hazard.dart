// lib/models/road_hazard.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum HazardType { speedBreaker, pothole, roughPatch }

extension HazardTypeExt on HazardType {
  String get label {
    switch (this) {
      case HazardType.speedBreaker: return 'Speed Breaker';
      case HazardType.pothole:      return 'Pothole';
      case HazardType.roughPatch:   return 'Rough Patch';
    }
  }

  String get emoji {
    switch (this) {
      case HazardType.speedBreaker: return '🚧';
      case HazardType.pothole:      return '🕳️';
      case HazardType.roughPatch:   return '〰️';
    }
  }
}

class RoadHazard {
  final String id;
  final double latitude;
  final double longitude;
  final HazardType type;
  final double severity;       // 0.0 – 1.0
  final int reportCount;
  final DateTime firstReported;
  final DateTime lastReported;
  final String? reportedBy;

  const RoadHazard({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.severity,
    required this.reportCount,
    required this.firstReported,
    required this.lastReported,
    this.reportedBy,
  });

  factory RoadHazard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawType = data['type'] as int? ?? 0;
    final clampedType = rawType.clamp(0, HazardType.values.length - 1);
    final first = (data['firstReported'] as Timestamp?)?.toDate();
    final last = (data['lastReported'] as Timestamp?)?.toDate();
    if (first == null || last == null) {
      throw StateError('hazard ${doc.id} missing firstReported/lastReported');
    }
    return RoadHazard(
      id: doc.id,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      type: HazardType.values[clampedType],
      severity: (data['severity'] as num? ?? 0.5).toDouble().clamp(0.0, 1.0),
      reportCount: data['reportCount'] as int? ?? 1,
      firstReported: first,
      lastReported: last,
      reportedBy: data['reportedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'type': type.index,
    'severity': severity,
    'reportCount': reportCount,
    'firstReported': Timestamp.fromDate(firstReported),
    'lastReported': Timestamp.fromDate(lastReported),
    if (reportedBy != null) 'reportedBy': reportedBy,
  };

  RoadHazard copyWith({int? reportCount, double? severity, DateTime? lastReported}) =>
      RoadHazard(
        id: id,
        latitude: latitude,
        longitude: longitude,
        type: type,
        severity: severity ?? this.severity,
        reportCount: reportCount ?? this.reportCount,
        firstReported: firstReported,
        lastReported: lastReported ?? this.lastReported,
        reportedBy: reportedBy,
      );

  /// True when another hazard is within ~50 m of this one
  bool isNear(double lat, double lng) {
    const deg = 0.0005; // ~55 m
    return (latitude - lat).abs() < deg && (longitude - lng).abs() < deg;
  }
}
