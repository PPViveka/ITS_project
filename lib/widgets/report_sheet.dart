// lib/widgets/report_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/road_hazard.dart';
import '../services/alert_service.dart';
import '../services/location_service.dart';
import '../screens/home_screen.dart' show AppColors;

class ReportSheet extends StatefulWidget {
  const ReportSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const ReportSheet(),
      );

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  HazardType _selected = HazardType.speedBreaker;
  double _severity = 0.5;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 20,
          left: 20,
          right: 20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: c.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Report a Hazard',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Tap to select type and rate severity',
              style: TextStyle(color: c.textSecondary, fontSize: 12)),
          const SizedBox(height: 20),

          // Type selector
          Row(
            children: HazardType.values.map((t) {
              final sel = _selected == t;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selected = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 4),
                    decoration: BoxDecoration(
                      color: sel
                          ? c.accent.withValues(alpha: 0.2)
                          : c.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel
                              ? c.accent
                              : c.card.withValues(alpha: 0)),
                    ),
                    child: Column(
                      children: [
                        Text(t.emoji,
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(t.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: sel ? c.accent : c.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Severity slider
          Row(
            children: [
              Text('Severity: ',
                  style: TextStyle(color: c.textSecondary, fontSize: 13)),
              Text('${(_severity * 10).toStringAsFixed(1)}/10',
                  style: TextStyle(
                      color: _severityColor(_severity, c),
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ],
          ),
          Slider(
            value: _severity,
            onChanged: (v) => setState(() => _severity = v),
            activeColor: _severityColor(_severity, c),
            inactiveColor: c.card,
          ),
          const SizedBox(height: 20),

          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Report',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Color _severityColor(double s, AppColors c) {
    if (s >= 0.7) return c.danger;
    if (s >= 0.4) return c.warning;
    return c.safe;
  }

  Future<void> _submit() async {
    final loc = context.read<LocationService>();
    final alert = context.read<AlertService>();
    final messenger = ScaffoldMessenger.of(context);
    final pos = loc.current;
    if (pos == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('GPS not ready yet. Try again.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await alert.reportHazard(
        lat: pos.latitude,
        lng: pos.longitude,
        type: _selected,
        severity: _severity,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Report failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
