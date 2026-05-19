import 'dart:math';

class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

List<LatLng> decodePolyline(String encoded) {
  List<LatLng> points = [];
  int index = 0, len = encoded.length;
  int lat = 0, lng = 0;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      if (index >= len) return points;
      b = encoded.codeUnitAt(index++) - 63;
      if (shift < 30) {
        result |= (b & 0x1f) << shift;
      }
      shift += 5;
    } while (b >= 0x20);
    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      if (index >= len) return points;
      b = encoded.codeUnitAt(index++) - 63;
      if (shift < 30) {
        result |= (b & 0x1f) << shift;
      }
      shift += 5;
    } while (b >= 0x20);
    int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    final pointLat = lat / 1E5;
    final pointLng = lng / 1E5;
    
    if (pointLat >= 8.0 && pointLat <= 38.0 && pointLng >= 68.0 && pointLng <= 98.0) {
      points.add(LatLng(pointLat, pointLng));
    }
  }
  return points;
}

void main() {
  final poly = 'aqdnA{erxM??CJEPABUv@GPA@GTKLGGJMBI@GL[BMTw@DOTu@HWLa@C?ICE?aDmAHg@KYQQ[QOA]BKF';
  final pts = decodePolyline(poly);
  print('Decoded ${pts.length} points:');
  for (var p in pts) {
    print(p);
  }
}
