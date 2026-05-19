// lib/screens/map_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/alert_service.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../models/road_hazard.dart';
import 'home_screen.dart' show AppColors;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapCtrl = MapController();
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  bool _loading = true;

  LatLng? _destination;
  List<RouteOption> _routes = [];
  int _selectedRouteIdx = 0;
  List<RoadHazard> _allHazards = [];

  LocationService? _locationService;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  Position? _lastPos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loc = Provider.of<LocationService>(context);
    final pos = loc.current;
    if (pos?.latitude != _lastPos?.latitude || pos?.longitude != _lastPos?.longitude) {
      final isFirstLock = _lastPos == null && pos != null;
      _lastPos = pos;
      _locationService = loc;
      _loadData();
      
      if (isFirstLock) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 14.5);
        });
      }
    }
  }

  LatLng? _lastLoadedPos;

  Future<void> _loadData() async {
    LatLng center;
    try {
      center = _mapCtrl.camera.center;
    } catch (_) {
      final pos = _locationService?.current;
      center = pos != null ? LatLng(pos.latitude, pos.longitude) : const LatLng(12.9716, 77.5946);
    }

    if (_lastLoadedPos != null) {
      final dist = Geolocator.distanceBetween(
        center.latitude, center.longitude,
        _lastLoadedPos!.latitude, _lastLoadedPos!.longitude,
      );
      if (dist < 300.0 && _allHazards.isNotEmpty) {
        return;
      }
    }
    _lastLoadedPos = center;
    
    final hazards = await context.read<AlertService>().fetchAll(center.latitude, center.longitude);
    if (!mounted) return;
    setState(() {
      _allHazards = hazards;
      _loading = false;
    });
    _updateMarkers();
  }

  Future<void> _onMapLongPress(TapPosition tapPosition, LatLng dest) async {
    setState(() {
      _destination = dest;
      _routes = [];
      _polylines = [];
      _loading = true;
    });
    _updateMarkers();

    final pos = context.read<LocationService>().current;
    final origin = pos != null ? LatLng(pos.latitude, pos.longitude) : const LatLng(12.9716, 77.5946);
    
    final opts = await RoutingService.fetchSafeRoutes(origin, dest, _allHazards);

    if (!mounted) return;
    setState(() {
      _routes = opts;
      _selectedRouteIdx = 0;
      _loading = false;
    });
    _updatePolylines();
    
    if (opts.isNotEmpty) {
      double minLat = origin.latitude, maxLat = origin.latitude;
      double minLng = origin.longitude, maxLng = origin.longitude;
      for (var p in opts.first.points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      
      _mapCtrl.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
          padding: const EdgeInsets.all(40.0),
        )
      );
    }
  }

  void _updateMarkers() {
    final List<Marker> newMarkers = _allHazards.map((h) => _buildMarker(h)).toList();
    
    if (_destination != null) {
      newMarkers.add(Marker(
        point: _destination!,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
      ));
    }
    
    final pos = context.read<LocationService>().current;
    if (pos != null) {
      newMarkers.add(Marker(
        point: LatLng(pos.latitude, pos.longitude),
        width: 20,
        height: 20,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ));
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  void _updatePolylines() {
    final List<Polyline> newPolylines = [];
    for (int i = 0; i < _routes.length; i++) {
      final isSelected = i == _selectedRouteIdx;
      newPolylines.add(Polyline(
        points: _routes[i].points,
        color: isSelected ? const Color.fromRGBO(46, 204, 113, 1.0) : const Color.fromRGBO(136, 153, 170, 0.5),
        strokeWidth: isSelected ? 5.0 : 3.0,
      ));
    }
    setState(() {
      _polylines = newPolylines;
    });
  }

  Marker _buildMarker(RoadHazard h) {
    return Marker(
      point: LatLng(h.latitude, h.longitude),
      width: 30,
      height: 30,
      child: Center(
        child: Text(h.type.emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final loc = context.watch<LocationService>();
    final pos = loc.current;

    final initialCam = pos != null
          ? LatLng(pos.latitude, pos.longitude)
          : const LatLng(12.9716, 77.5946);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        title: Text('Hazard Map',
            style: TextStyle(color: c.accent, fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: c.textSecondary),
            onPressed: () {
              setState(() {
                _destination = null;
                _routes = [];
                _polylines = [];
              });
              _loadData();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: initialCam,
              initialZoom: 14.5,
              onLongPress: _onMapLongPress,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.speedbreakeralert.app',
              ),
              PolylineLayer(
                polylines: _polylines,
              ),
              MarkerLayer(
                markers: _markers,
              ),
            ],
          ),
          if (_loading)
            Center(child: CircularProgressIndicator(color: c.accent)),
          
          // Legend
          Positioned(
            top: 16,
            left: 12,
            child: _Legend(),
          ),

          // Zoom & Recenter Controls (Laptop User Friendly)
          Positioned(
            right: 16,
            bottom: _routes.isNotEmpty ? 170 : 80,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  heroTag: 'zoom_in',
                  backgroundColor: c.surface.withValues(alpha: 0.95),
                  child: Icon(Icons.add, color: c.accent),
                  onPressed: () {
                    final currZoom = _mapCtrl.camera.zoom;
                    _mapCtrl.move(_mapCtrl.camera.center, currZoom + 1.0);
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  heroTag: 'zoom_out',
                  backgroundColor: c.surface.withValues(alpha: 0.95),
                  child: Icon(Icons.remove, color: c.accent),
                  onPressed: () {
                    final currZoom = _mapCtrl.camera.zoom;
                    _mapCtrl.move(_mapCtrl.camera.center, currZoom - 1.0);
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  heroTag: 'recenter',
                  backgroundColor: c.surface.withValues(alpha: 0.95),
                  child: Icon(Icons.my_location, color: c.accent),
                  onPressed: () {
                    final pos = _locationService?.current;
                    if (pos != null) {
                      _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 14.5);
                    } else {
                      _mapCtrl.move(const LatLng(12.9716, 77.5946), 14.5);
                    }
                  },
                ),
              ],
            ),
          ),

          // Route Selector
          if (_routes.isNotEmpty)
            Positioned(
              bottom: 24,
              left: 12,
              right: 12,
              child: _RouteSelector(
                routes: _routes,
                selectedIndex: _selectedRouteIdx,
                onSelect: (i) {
                  setState(() {
                    _selectedRouteIdx = i;
                    _updatePolylines();
                  });
                },
              ),
            ),
          
          // Hint
          if (_routes.isEmpty && !_loading)
            Positioned(
              bottom: 24,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.touch_app, color: c.accent, size: 20),
                    const SizedBox(width: 12),
                    Text('Long-press on map to calculate Safe Route', 
                      style: TextStyle(color: c.textPrimary, fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RouteSelector extends StatelessWidget {
  final List<RouteOption> routes;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const _RouteSelector({required this.routes, required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.card, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Available Routes', style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: routes.length,
              itemBuilder: (_, i) {
                final r = routes[i];
                final isSelected = i == selectedIndex;
                return GestureDetector(
                  onTap: () => onSelect(i),
                  child: Container(
                    width: 220,
                    margin: const EdgeInsets.only(right: 12, bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? c.safe.withValues(alpha: 0.1) : c.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? c.safe : c.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.route, color: isSelected ? c.safe : c.textSecondary, size: 18),
                            const SizedBox(width: 8),
                            Text('${(r.distance / 1000).toStringAsFixed(1)} km', 
                              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text('${(r.duration / 60).round()} min', 
                              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: r.safetyScore > 80 ? c.safe.withValues(alpha: 0.2) : c.warning.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Safety: ${r.safetyScore.round()}', 
                                style: TextStyle(color: r.safetyScore > 80 ? c.safe : c.warning, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Text('${r.hazards.length} hazards', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendRow('🔴', 'Pothole', Colors.red),
          const SizedBox(height: 4),
          _LegendRow('🟠', 'Speed Breaker', Colors.orange),
          const SizedBox(height: 4),
          _LegendRow('🟡', 'Rough Patch', Colors.yellow),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String emoji, label;
  final Color color;
  const _LegendRow(this.emoji, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: Theme.of(context).extension<AppColors>()!.textPrimary,
                fontSize: 11)),
      ],
    );
  }
}
