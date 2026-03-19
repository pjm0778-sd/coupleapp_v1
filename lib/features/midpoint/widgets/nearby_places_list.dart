import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme.dart';
import '../models/midpoint_result.dart';

class NearbyPlacesList extends StatelessWidget {
  final List<NearbyPlace> places;
  final String midpointCityName;
  final VoidCallback? onAddSchedule;

  const NearbyPlacesList({
    super.key,
    required this.places,
    required this.midpointCityName,
    this.onAddSchedule,
  });

  static const _categoryIcons = {
    '음식점': '🍽',
    '카페': '☕',
    '관광명소': '🏛',
    '숙박': '🏨',
  };

  String _icon(String category) {
    for (final entry in _categoryIcons.entries) {
      if (category.contains(entry.key)) return entry.value;
    }
    return '📍';
  }

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) {
      return const Center(
        child: Text('주변 장소 정보를 불러오지 못했습니다.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      );
    }

    return Column(
      children: places.map((place) => _PlaceItem(
            place: place,
            icon: _icon(place.category),
            onAddSchedule: onAddSchedule,
          )).toList(),
    );
  }
}

class _PlaceItem extends StatelessWidget {
  final NearbyPlace place;
  final String icon;
  final VoidCallback? onAddSchedule;

  const _PlaceItem({
    required this.place,
    required this.icon,
    this.onAddSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(place.shortCategory,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          // 카카오맵 링크
          if (place.kakaoUrl != null)
            IconButton(
              icon: const Icon(Icons.map_outlined, size: 20),
              color: AppTheme.textSecondary,
              onPressed: () async {
                final uri = Uri.parse(place.kakaoUrl!);
                if (await canLaunchUrl(uri)) launchUrl(uri);
              },
            ),
          // 일정 추가
          if (onAddSchedule != null)
            TextButton(
              onPressed: onAddSchedule,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accent,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('+ 일정',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
