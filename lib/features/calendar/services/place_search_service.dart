import '../../../core/supabase_client.dart';

class PlaceResult {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String? category;

  const PlaceResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.category,
  });
}

class PlaceSearchService {
  Future<List<PlaceResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final res = await supabase.functions.invoke(
      'kakao-place-search',
      queryParameters: {'query': query.trim()},
    );

    final data = res.data as Map<String, dynamic>?;
    final places = data?['places'] as List?;
    if (places == null) return [];

    return places.map((p) {
      final m = p as Map<String, dynamic>;
      return PlaceResult(
        name: m['name'] as String,
        address: m['address'] as String? ?? '',
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        category: m['category'] as String?,
      );
    }).toList();
  }
}
