import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme.dart';
import '../models/midpoint_result.dart';

class MidpointMapWidget extends StatelessWidget {
  final MidpointCity city;
  final LatLng myOrigin;
  final LatLng partnerOrigin;
  final List<NearbyPlace> places;

  const MidpointMapWidget({
    super.key,
    required this.city,
    required this.myOrigin,
    required this.partnerOrigin,
    required this.places,
  });

  @override
  Widget build(BuildContext context) {
    final midLatLng = LatLng(city.lat, city.lng);

    return SizedBox(
      height: 260,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: midLatLng,
            initialZoom: 9,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.coupleapp.v1',
            ),
            MarkerLayer(markers: [
              // 내 출발지
              _buildMarker(myOrigin, '나', AppTheme.accent),
              // 상대방 출발지
              _buildMarker(partnerOrigin, '상대', Colors.blue[400]!),
              // 중간지점
              _buildMidpointMarker(midLatLng, city.name),
              // 주변 장소 (최대 5개)
              ...places.take(5).map((p) => _buildPlaceMarker(
                    LatLng(p.lat, p.lng),
                  )),
            ]),
          ],
        ),
      ),
    );
  }

  Marker _buildMarker(LatLng point, String label, Color color) {
    return Marker(
      point: point,
      width: 60,
      height: 44,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          Icon(Icons.location_pin, color: color, size: 22),
        ],
      ),
    );
  }

  Marker _buildMidpointMarker(LatLng point, String cityName) {
    return Marker(
      point: point,
      width: 80,
      height: 52,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(cityName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          const Icon(Icons.location_pin, color: AppTheme.primary, size: 26),
        ],
      ),
    );
  }

  Marker _buildPlaceMarker(LatLng point) {
    return Marker(
      point: point,
      width: 20,
      height: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green[400],
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }
}
