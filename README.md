# 🛣️ Road Guard — Speed Breaker & Pothole Alert System

Crowdsourced road quality intelligence. Automatically detects bumps via accelerometer,
logs GPS location to Firebase, and alerts nearby drivers in real time.

---

## Tech Stack

| Layer | Technology |
|---|---|
| App framework | Flutter 3.x (Dart) |
| State management | Provider |
| Backend / DB | Firebase Firestore |
| Auth | Firebase Auth (anonymous) |
| Maps | Google Maps Flutter |
| Bump detection | sensors_plus (accelerometer) |
| Location | geolocator |
| Notifications | flutter_local_notifications |
| Background | flutter_background_service |
| Offline cache | shared_preferences + connectivity_plus |

---

## Project Structure

```
lib/
├── main.dart                    # App entry, theme, providers
├── firebase_options.dart        # Firebase config (replace placeholders)
├── models/
│   └── road_hazard.dart         # RoadHazard data model + HazardType enum
├── services/
│   ├── location_service.dart    # GPS stream + permission
│   ├── detection_service.dart   # Accelerometer bump detection
│   ├── alert_service.dart       # Firestore CRUD
│   ├── notification_service.dart# Local push notifications
│   ├── proximity_service.dart   # Periodic hazard-ahead checker
│   ├── background_service.dart  # Background bump detection
│   ├── offline_queue.dart       # Offline cache + auto-sync
│   └── speed_gate.dart          # Speed filter (suppress parked false positives)
├── screens/
│   ├── splash_screen.dart       # Animated launch + permission init
│   ├── home_screen.dart         # Main shell (bottom nav + AppColors)
│   ├── map_screen.dart          # Google Maps with hazard markers
│   ├── stats_screen.dart        # Dashboard with charts + hotspots
│   └── settings_screen.dart     # Sensitivity, radius, background toggle
└── widgets/
    ├── hazard_card.dart          # Nearby hazard list item
    ├── detection_indicator.dart  # Pulsing dot + last event label
    ├── stat_chip.dart            # GPS/nearby pill chip
    └── report_sheet.dart         # Manual report bottom sheet
```

---

## Setup Guide

### 1. Create a Firebase project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Create a new project named `road-guard`
3. Enable **Cloud Firestore** (start in test mode for dev)
4. Enable **Authentication → Anonymous** sign-in

### 2. Add Firebase to the Flutter app

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=road-guard
```

This generates `lib/firebase_options.dart` automatically.

### 3. Google Maps API key

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Enable **Maps SDK for Android** and **Maps SDK for iOS**
3. Create an API key

**Android** — edit `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_KEY_HERE" />
```

**iOS** — edit `ios/Runner/AppDelegate.swift`:
```swift
import GoogleMaps
GMSServices.provideAPIKey("YOUR_KEY_HERE")
```

Also add to `ios/Runner/Info.plist`:
```xml
<key>GMSApiKey</key>
<string>YOUR_KEY_HERE</string>
```

### 4. Deploy Firestore rules & indexes

```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

### 5. Install dependencies and run

```bash
flutter pub get
flutter run
```

---

## Detection Thresholds (tunable in `detection_service.dart`)

| Constant | Default | Meaning |
|---|---|---|
| `_potholeThreshold` | 18.0 m/s² | Sharp vertical spike |
| `_speedBreakerThresh` | 12.0 m/s² | Moderate sustained rise |
| `_roughPatchThresh` | 9.0 m/s² | Repeated mild variance |
| `_cooldownMs` | 2500 ms | Min time between events |

Users can adjust sensitivity in **Settings → Detection sensitivity**.

---

## Firestore Data Schema

```
hazards/{id}
  latitude:      float
  longitude:     float
  type:          int   (0=speedBreaker, 1=pothole, 2=roughPatch)
  severity:      float (0.0–1.0)
  reportCount:   int
  firstReported: timestamp
  lastReported:  timestamp
  reportedBy:    string (uid, optional)
  source:        string ("manual" | "auto" | "background")
```

Hazards older than **30 days** are excluded from map/list queries.
Duplicate reports within **~50 m** of the same type are merged and
increment `reportCount` + update weighted `severity`.

---

## Key Features

- **Auto detection** — accelerometer spike detection with 3 hazard types
- **Speed gate** — ignores bumps when speed < 5 km/h (configurable)
- **Manual report** — bottom sheet with type picker + severity slider
- **Proximity alerts** — local notifications when within 250 m of a hazard
- **Dark map** — custom styled Google Maps in dark theme
- **Offline queue** — caches reports locally and auto-syncs on reconnect
- **Background detection** — foreground service keeps monitoring when minimized
- **Duplicate merging** — nearby same-type hazards are aggregated, not duplicated
- **Stats dashboard** — total counts, type breakdown, top hotspots

---

## License

MIT
