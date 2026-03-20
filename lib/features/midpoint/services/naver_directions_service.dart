import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart' show supabaseUrl, supabaseAnonKey;
import '../models/midpoint_input.dart';

class DirectionsResult {
  final double distanceKm;
  final int durationMinutes;
  final int tollFare;

  const DirectionsResult({
    required this.distanceKm,
    required this.durationMinutes,
    required this.tollFare,
  });

  int fuelCost(CarType type) {
    return type == CarType.electric
        ? (distanceKm / 6 * 300).round()
        : (distanceKm / 12 * 1700).round();
  }

  int totalCost(CarType type) => fuelCost(type) + tollFare;
}

class NaverDirectionsService {
  static const String _endpoint = '$supabaseUrl/functions/v1/naver-directions-proxy';

  Future<DirectionsResult?> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      // Naver API는 "경도,위도" 순서
      final start = '${origin.longitude},${origin.latitude}';
      final goal = '${destination.longitude},${destination.latitude}';

      final uri = Uri.parse('$_endpoint?start=$start&goal=$goal');
      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ''}',
        'apikey': supabaseAnonKey,
      });

      if (res.statusCode != 200) {
        debugPrint('[NaverDirections] error ${res.statusCode}: ${res.body}');
        return null;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data.containsKey('error')) {
        debugPrint('[NaverDirections] API error: ${data['error']}');
        return null;
      }

      return DirectionsResult(
        distanceKm: (data['distanceKm'] as num).toDouble(),
        durationMinutes: data['durationMinutes'] as int,
        tollFare: data['tollFare'] as int,
      );
    } catch (e) {
      debugPrint('[NaverDirections] exception: $e');
      return null;
    }
  }
}
