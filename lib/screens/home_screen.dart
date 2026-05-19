// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/detection_service.dart';
import '../services/location_service.dart';
import '../services/alert_service.dart';
import '../services/notification_service.dart';
import '../services/proximity_service.dart';
import '../models/road_hazard.dart';
import '../widgets/hazard_card.dart';
import '../widgets/detection_indicator.dart';
import '../widgets/stat_chip.dart';
import '../widgets/report_sheet.dart';
import 'map_screen.dart';
import 'stats_screen.dart';

// ── AppColors theme extension ─────────────────────────────────────────────────
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg, required this.surface, required this.card,
    required this.accent, required this.accentGlow,
    required this.safe, required this.warning, required this.danger,
    required this.textPrimary, required this.textSecondary,
  });

  final Color bg, surface, card, accent, accentGlow;
  final Color safe, warning, danger, textPrimary, textSecondary;

  @override
  AppColors copyWith({
    Color? bg, Color? surface, Color? card,
    Color? accent, Color? accentGlow,
    Color? safe, Color? warning, Color? danger,
    Color? textPrimary, Color? textSecondary,
  }) => AppColors(
    bg: bg ?? this.bg, surface: surface ?? this.surface, card: card ?? this.card,
    accent: accent ?? this.accent, accentGlow: accentGlow ?? this.accentGlow,
    safe: safe ?? this.safe, warning: warning ?? this.warning, danger: danger ?? this.danger,
    textPrimary: textPrimary ?? this.textPrimary, textSecondary: textSecondary ?? this.textSecondary,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!, surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!, accent: Color.lerp(accent, other.accent, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      safe: Color.lerp(safe, other.safe, t)!, warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}

// ── HomeScreen ────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  late ProximityService _proximity;

  @override
  void initState() {
    super.initState();
    final det = context.read<DetectionService>();
    final loc = context.read<LocationService>();
    final alert = context.read<AlertService>();

    _proximity = ProximityService(loc, alert);

    loc.startTracking().then((_) {
      if (loc.current != null) {
        alert.listenNearby(loc.current!.latitude, loc.current!.longitude);
        _proximity.start();
      }
    });

    det.onDetected = (event) async {
      final pos = loc.current;
      if (pos == null) return;
      final sev = (event.magnitude / 25.0).clamp(0.0, 1.0);
      await alert.reportHazard(
        lat: pos.latitude,
        lng: pos.longitude,
        type: event.type,
        severity: sev,
      );
      await NotificationService.showDetected(RoadHazard(
        id: '',
        latitude: pos.latitude,
        longitude: pos.longitude,
        type: event.type,
        severity: sev,
        reportCount: 1,
        firstReported: DateTime.now(),
        lastReported: DateTime.now(),
      ));
    };
  }

  @override
  void dispose() {
    _proximity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final det = context.watch<DetectionService>();
    final loc = context.watch<LocationService>();
    final alert = context.watch<AlertService>();

    final pages = [
      _DashboardPage(det: det, loc: loc, alert: alert),
      const MapScreen(),
      const StatsScreen(),
    ];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        title: Row(children: [
          const Text('🛣️ ', style: TextStyle(fontSize: 22)),
          Text('ROAD GUARD',
              style: TextStyle(
                color: c.accent,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                fontSize: 17,
              )),
        ]),
        actions: [
          GestureDetector(
            onTap: () {
              if (det.active) { det.stop(); } else { det.start(); loc.startTracking(); }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: det.active ? c.safe.withValues(alpha: 0.15) : c.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: det.active ? c.safe : c.danger, width: 1.2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: det.active ? c.safe : c.danger),
                ),
                const SizedBox(width: 6),
                Text(det.active ? 'ON' : 'OFF',
                    style: TextStyle(
                      color: det.active ? c.safe : c.danger,
                      fontWeight: FontWeight.bold, fontSize: 12,
                    )),
              ]),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _navIndex, children: pages),
      bottomNavigationBar: _BottomNav(
          index: _navIndex, onTap: (i) => setState(() => _navIndex = i), c: c),
      floatingActionButton: _navIndex == 0
          ? FloatingActionButton(
              backgroundColor: c.accent,
              tooltip: 'Report a hazard manually',
              onPressed: () => ReportSheet.show(context),
              child: const Icon(Icons.add_location_alt, color: Colors.white),
            )
          : null,
    );
  }
}

// ── Dashboard page ─────────────────────────────────────────────────────────────
class _DashboardPage extends StatelessWidget {
  final DetectionService det;
  final LocationService loc;
  final AlertService alert;
  const _DashboardPage({required this.det, required this.loc, required this.alert});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Column(children: [
      Container(
        color: c.card,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          DetectionIndicator(active: det.active, lastEvent: det.lastEvent),
          const Spacer(),
          StatChip(label: 'Nearby', value: '${alert.nearby.length}',
              color: alert.nearby.isEmpty ? c.textSecondary : c.warning),
          const SizedBox(width: 8),
          StatChip(label: 'GPS', value: loc.current != null ? 'ON' : '...',
              color: loc.current != null ? c.safe : c.textSecondary),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(children: [
          Text('⚠️  Nearby Hazards',
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          const Spacer(),
          Text('within 300 m', style: TextStyle(color: c.textSecondary, fontSize: 11)),
        ]),
      ),
      Expanded(
        child: alert.nearby.isEmpty
            ? _EmptyState(c: c)
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: alert.nearby.length,
                itemBuilder: (_, i) => HazardCard(hazard: alert.nearby[i]),
              ),
      ),
    ]);
  }
}

class _EmptyState extends StatelessWidget {
  final AppColors c;
  const _EmptyState({required this.c});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('✅', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 12),
      Text('Road looks clear!',
          style: TextStyle(color: c.safe, fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('No hazards reported within 300 m',
          style: TextStyle(color: c.textSecondary, fontSize: 12)),
      const SizedBox(height: 28),
      Text('Tap  ＋  to report a hazard manually',
          style: TextStyle(color: c.textSecondary, fontSize: 11)),
    ]),
  );
}

// ── Bottom navigation ──────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final AppColors c;
  const _BottomNav({required this.index, required this.onTap, required this.c});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: c.surface,
      border: Border(top: BorderSide(color: c.card, width: 1)),
    ),
    child: SafeArea(
      child: Row(children: [
        _NavItem(Icons.dashboard_outlined, 'Dashboard', 0, index, onTap, c),
        _NavItem(Icons.map_outlined, 'Map', 1, index, onTap, c),
        _NavItem(Icons.bar_chart_outlined, 'Stats', 2, index, onTap, c),
      ]),
    ),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int myIndex, current;
  final ValueChanged<int> onTap;
  final AppColors c;
  const _NavItem(this.icon, this.label, this.myIndex, this.current, this.onTap, this.c);

  @override
  Widget build(BuildContext context) {
    final selected = myIndex == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(myIndex),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: selected ? c.accent : c.textSecondary, size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
              color: selected ? c.accent : c.textSecondary,
              fontSize: 10,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            )),
          ]),
        ),
      ),
    );
  }
}
