// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/background_service.dart';
import '../services/detection_service.dart';
import '../services/speed_gate.dart';
import 'home_screen.dart' show AppColors;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Defaults
  double _sensitivityThresh = 12.0;   // m/s²
  double _alertRadius = 250.0;         // metres
  bool _backgroundDetection = false;
  bool _vibrate = true;
  bool _sound = true;
  double _minSpeed = 5.0;              // km/h below which we ignore bumps
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _sensitivityThresh = p.getDouble('sens_thresh') ?? 12.0;
      _alertRadius       = p.getDouble('alert_radius') ?? 250.0;
      _backgroundDetection = p.getBool('bg_detect') ?? false;
      _vibrate           = p.getBool('vibrate') ?? true;
      _sound             = p.getBool('sound') ?? true;
      _minSpeed          = p.getDouble('min_speed') ?? 5.0;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('sens_thresh', _sensitivityThresh);
    await p.setDouble('alert_radius', _alertRadius);
    await p.setBool('bg_detect', _backgroundDetection);
    await p.setBool('vibrate', _vibrate);
    await p.setBool('sound', _sound);
    await p.setDouble('min_speed', _minSpeed);

    // Push live changes to running services.
    if (!mounted) return;
    context.read<DetectionService>().updateSensitivity(_sensitivityThresh);
    context.read<SpeedGate>().updateMinSpeed(_minSpeed);

    final running = await BackgroundDetectionService.isRunning();
    if (_backgroundDetection && !running) {
      await BackgroundDetectionService.start();
    } else if (!_backgroundDetection && running) {
      await BackgroundDetectionService.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        title: Text('Settings',
            style: TextStyle(
                color: c.accent, fontWeight: FontWeight.bold, letterSpacing: 2)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader('Detection', c),
                _SliderTile(
                  label: 'Sensitivity threshold',
                  subtitle:
                      'Min G-force to flag a bump (lower = more sensitive)',
                  value: _sensitivityThresh,
                  min: 6, max: 22, divisions: 16,
                  unit: ' m/s²',
                  color: c.accent,
                  c: c,
                  onChanged: (v) {
                    setState(() => _sensitivityThresh = v);
                    _save();
                  },
                ),
                _SliderTile(
                  label: 'Minimum speed',
                  subtitle: 'Ignore bumps below this speed (avoids false positives while parked)',
                  value: _minSpeed,
                  min: 0, max: 20, divisions: 20,
                  unit: ' km/h',
                  color: c.warning,
                  c: c,
                  onChanged: (v) {
                    setState(() => _minSpeed = v);
                    _save();
                  },
                ),
                _ToggleTile(
                  label: 'Background detection',
                  subtitle: 'Keep monitoring when app is minimized',
                  value: _backgroundDetection,
                  c: c,
                  onChanged: (v) {
                    setState(() => _backgroundDetection = v);
                    _save();
                  },
                ),

                const SizedBox(height: 16),
                _SectionHeader('Alerts', c),
                _SliderTile(
                  label: 'Alert radius',
                  subtitle: 'Distance at which to notify about incoming hazards',
                  value: _alertRadius,
                  min: 100, max: 600, divisions: 5,
                  unit: ' m',
                  color: c.safe,
                  c: c,
                  onChanged: (v) {
                    setState(() => _alertRadius = v);
                    _save();
                  },
                ),
                _ToggleTile(
                  label: 'Vibration',
                  subtitle: 'Vibrate on hazard alerts',
                  value: _vibrate,
                  c: c,
                  onChanged: (v) { setState(() => _vibrate = v); _save(); },
                ),
                _ToggleTile(
                  label: 'Sound',
                  subtitle: 'Play sound on hazard alerts',
                  value: _sound,
                  c: c,
                  onChanged: (v) { setState(() => _sound = v); _save(); },
                ),

                const SizedBox(height: 16),
                _SectionHeader('About', c),
                _InfoTile('Version', '1.0.0', c),
                _InfoTile('Data retention', '30 days', c),
                _InfoTile('Hazard merge radius', '~50 m', c),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final AppColors c;
  const _SectionHeader(this.title, this.c);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: TextStyle(
                color: c.accent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
      );
}

class _SliderTile extends StatelessWidget {
  final String label, subtitle, unit;
  final double value, min, max;
  final int divisions;
  final Color color;
  final AppColors c;
  final ValueChanged<double> onChanged;
  const _SliderTile({
    required this.label, required this.subtitle,
    required this.value, required this.min, required this.max,
    required this.divisions, required this.unit, required this.color,
    required this.c, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: c.textSecondary, fontSize: 10)),
            ])),
            Text('${value.toStringAsFixed(0)}$unit',
                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
          ]),
          Slider(
            value: value, min: min, max: max, divisions: divisions,
            activeColor: color, inactiveColor: c.surface,
            onChanged: onChanged,
          ),
        ]),
      );
}

class _ToggleTile extends StatelessWidget {
  final String label, subtitle;
  final bool value;
  final AppColors c;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({
    required this.label, required this.subtitle,
    required this.value, required this.c, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: c.textSecondary, fontSize: 10)),
          ])),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: c.accent,
          ),
        ]),
      );
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  final AppColors c;
  const _InfoTile(this.label, this.value, this.c);
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
          const Spacer(),
          Text(value, style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      );
}
