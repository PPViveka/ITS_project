// lib/screens/stats_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/road_hazard.dart';
import '../services/alert_service.dart';
import '../services/location_service.dart';
import 'home_screen.dart' show AppColors;

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<RoadHazard> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pos = context.read<LocationService>().current;
    final data = await context
        .read<AlertService>()
        .fetchAll(pos?.latitude, pos?.longitude);
    if (mounted) setState(() { _all = data; _loading = false; });
  }

  Map<HazardType, int> get _counts {
    final m = <HazardType, int>{};
    for (final h in _all) m[h.type] = (m[h.type] ?? 0) + 1;
    return m;
  }

  double get _avgSeverity =>
      _all.isEmpty ? 0 : _all.map((h) => h.severity).reduce((a, b) => a + b) / _all.length;

  int get _totalReports => _all.fold(0, (s, h) => s + h.reportCount);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        title: Text('Road Intelligence',
            style: TextStyle(color: c.accent, fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: c.textSecondary),
            onPressed: () { setState(() => _loading = true); _load(); },
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary cards
                Row(children: [
                  _SummaryCard('Total Hazards', '${_all.length}', '🗺️', c.accent, c),
                  const SizedBox(width: 10),
                  _SummaryCard('Total Reports', '$_totalReports', '📢', c.warning, c),
                  const SizedBox(width: 10),
                  _SummaryCard('Avg Severity', '${(_avgSeverity * 10).toStringAsFixed(1)}', '📊', c.danger, c),
                ]),
                const SizedBox(height: 20),

                Text('By Type', style: TextStyle(
                    color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._counts.entries.map((e) => _TypeBar(
                  type: e.key,
                  count: e.value,
                  total: _all.length,
                  c: c,
                )),
                const SizedBox(height: 20),

                Text('Recent Hotspots', style: TextStyle(
                    color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._topHazards.map((h) => _HotspotRow(hazard: h, c: c)),
              ],
            ),
    );
  }

  List<RoadHazard> get _topHazards {
    final sorted = [..._all]..sort((a, b) => b.reportCount.compareTo(a.reportCount));
    return sorted.take(5).toList();
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value, emoji;
  final Color color;
  final AppColors c;
  const _SummaryCard(this.label, this.value, this.emoji, this.color, this.c);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _TypeBar extends StatelessWidget {
  final HazardType type;
  final int count, total;
  final AppColors c;
  const _TypeBar({required this.type, required this.count, required this.total, required this.c});

  @override
  Widget build(BuildContext context) {
    final frac = total == 0 ? 0.0 : count / total;
    final color = type == HazardType.pothole ? c.danger
        : type == HazardType.speedBreaker ? c.warning : c.safe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${type.emoji}  ${type.label}',
              style: TextStyle(color: c.textPrimary, fontSize: 13)),
          const Spacer(),
          Text('$count', style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: frac,
            backgroundColor: c.surface,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 7,
          ),
        ),
      ]),
    );
  }
}

class _HotspotRow extends StatelessWidget {
  final RoadHazard hazard;
  final AppColors c;
  const _HotspotRow({required this.hazard, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Text(hazard.type.emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hazard.type.label,
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
          Text('${hazard.latitude.toStringAsFixed(4)}, ${hazard.longitude.toStringAsFixed(4)}',
              style: TextStyle(color: c.textSecondary, fontSize: 10)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: c.warning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('${hazard.reportCount}×',
              style: TextStyle(color: c.warning, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ]),
    );
  }
}
