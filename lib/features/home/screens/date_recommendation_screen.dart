import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class DateRecommendationScreen extends StatefulWidget {
  final String? myCity;
  final String? partnerCity;
  final bool isLongDistance;

  const DateRecommendationScreen({
    super.key,
    this.myCity,
    this.partnerCity,
    this.isLongDistance = false,
  });

  @override
  State<DateRecommendationScreen> createState() =>
      _DateRecommendationScreenState();
}

class _DateRecommendationScreenState extends State<DateRecommendationScreen> {
  final _random = Random();
  late List<_RecommendationItem> _items;

  static const _pool = [
    _RecommendationItem(
      '야경 산책 데이트',
      '근처 강변/공원 야간 산책 후 카페 마무리',
      Icons.nightlight_round,
      [Color(0xFF6F63D6), Color(0xFF4A409E)],
    ),
    _RecommendationItem(
      '브런치 + 전시 데이트',
      '낮에는 브런치, 오후에는 사진 전시 관람',
      Icons.museum_outlined,
      [Color(0xFFDB8A59), Color(0xFF9F5D35)],
    ),
    _RecommendationItem(
      '원데이 클래스 체험',
      '도자기, 향수, 베이킹 중 하나를 함께 체험',
      Icons.brush_outlined,
      [Color(0xFF4AA6A3), Color(0xFF2D6F6C)],
    ),
    _RecommendationItem(
      '드라이브 + 전망대',
      '노을 시간대에 맞춘 드라이브 코스 추천',
      Icons.directions_car_outlined,
      [Color(0xFF4F7DD5), Color(0xFF31539C)],
    ),
    _RecommendationItem(
      '집데이트 테마 나이트',
      '서로 영화 1편씩 추천하고 홈시네마 구성',
      Icons.movie_outlined,
      [Color(0xFFB563A9), Color(0xFF7A3E72)],
    ),
    _RecommendationItem(
      '플레이리스트 교환 데이트',
      '각자 5곡씩 공유하고 코멘트 나누기',
      Icons.queue_music_outlined,
      [Color(0xFF5F9E6E), Color(0xFF3D6D49)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _items = _pickRecommendations();
  }

  List<_RecommendationItem> _pickRecommendations() {
    final copy = List<_RecommendationItem>.from(_pool)..shuffle(_random);
    return copy.take(3).toList();
  }

  String _locationHint() {
    final my = widget.myCity;
    final partner = widget.partnerCity;
    if (my == null || my.isEmpty || partner == null || partner.isEmpty) {
      return '위치 정보가 없어서 범용 데이트 코스로 추천했어요.';
    }
    if (widget.isLongDistance) {
      return '$my · $partner 장거리 커플 기준으로 부담 적은 코스를 우선 추천했어요.';
    }
    return '$my · $partner 생활권 기준으로 이동 동선을 고려했어요.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        title: const Text('데이트 추천'),
      ),
      body: Container(
        decoration: AppTheme.pageGradient,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
                boxShadow: const [AppTheme.subtleShadow],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.tips_and_updates_outlined,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _locationHint(),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ..._items.map((item) => _RecommendationCard(item: item)),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () =>
                    setState(() => _items = _pickRecommendations()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  '다른 추천 보기',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationItem {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;

  const _RecommendationItem(
    this.title,
    this.description,
    this.icon,
    this.gradient,
  );
}

class _RecommendationCard extends StatelessWidget {
  final _RecommendationItem item;

  const _RecommendationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            item.gradient.first.withValues(alpha: 0.92),
            item.gradient.last.withValues(alpha: 0.88),
          ],
        ),
        boxShadow: const [AppTheme.subtleShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
