import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'http://router.project-osrm.org/route/v1/driving/77.5946,12.9716;77.5960,12.9730?geometries=polyline&overview=full&alternatives=true';
  final res = await http.get(Uri.parse(url));
  print(res.body);
}
