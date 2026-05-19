// lib/widgets/detection_indicator.dart
import 'package:flutter/material.dart';
import '../services/detection_service.dart';
import '../models/road_hazard.dart';
import '../screens/home_screen.dart' show AppColors;

class DetectionIndicator extends StatefulWidget {
  final bool active;
  final DetectionEvent? lastEvent;
  const DetectionIndicator(
      {super.key, required this.active, this.lastEvent});

  @override
  State<DetectionIndicator> createState() => _DetectionIndicatorState();
}

class _DetectionIndicatorState extends State<DetectionIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _ring;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _ring = Tween<double>(begin: 0.6, end: 1.2).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final activeColor = widget.active ? c.safe : c.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulse dot
        SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.active)
                AnimatedBuilder(
                  animation: _ring,
                  builder: (_, __) => Container(
                    width: 28 * _ring.value,
                    height: 28 * _ring.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.safe.withValues(alpha: 0.2 * (1.2 - _ring.value)),
                    ),
                  ),
                ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeColor,
                  boxShadow: widget.active
                      ? [
                          BoxShadow(
                            color: c.safe.withValues(alpha: 0.6),
                            blurRadius: 8,
                          )
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.active ? 'Monitoring' : 'Inactive',
              style: TextStyle(
                color: activeColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (widget.lastEvent != null)
              Text(
                'Last: ${widget.lastEvent!.type.label}',
                style: TextStyle(color: c.textSecondary, fontSize: 10),
              ),
          ],
        ),
      ],
    );
  }
}
