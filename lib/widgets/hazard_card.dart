// lib/widgets/hazard_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/road_hazard.dart';
import '../services/location_service.dart';
import '../screens/home_screen.dart' show AppColors;

class HazardCard extends StatelessWidget {
  final RoadHazard hazard;
  const HazardCard({super.key, required this.hazard});

  Color _severityColor(double s, AppColors c) {
    if (s >= 0.7) return c.danger;
    if (s >= 0.4) return c.warning;
    return c.safe;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final loc = context.watch<LocationService>();
    final dist = loc.distanceTo(hazard.latitude, hazard.longitude);
    final sevColor = _severityColor(hazard.severity, c);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sevColor.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: sevColor.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Emoji badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: sevColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sevColor.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: Text(hazard.type.emoji,
                    style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        hazard.type.label,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      if (dist != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: c.accent.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            dist < 1000
                                ? '${dist.toStringAsFixed(0)} m'
                                : '${(dist / 1000).toStringAsFixed(1)} km',
                            style: TextStyle(
                                color: c.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Severity bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Severity  ',
                              style: TextStyle(
                                  color: c.textSecondary, fontSize: 11)),
                          Text(
                            '${(hazard.severity * 10).toStringAsFixed(1)}/10',
                            style: TextStyle(
                                color: sevColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: hazard.severity,
                          backgroundColor: c.surface,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(sevColor),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 12, color: c.textSecondary),
                      const SizedBox(width: 3),
                      Text('${hazard.reportCount} reports',
                          style: TextStyle(
                              color: c.textSecondary, fontSize: 11)),
                      const SizedBox(width: 10),
                      Icon(Icons.access_time,
                          size: 12, color: c.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        DateFormat('d MMM, hh:mm a')
                            .format(hazard.lastReported),
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
