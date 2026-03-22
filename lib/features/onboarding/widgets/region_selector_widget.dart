import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../profile/data/city_station_data.dart';

/// 도/광역시 → 시/군 계층 지역 선택 위젯
/// 역/터미널은 표시하지 않음 (자동 선택)
class RegionSelectorWidget extends StatefulWidget {
  final String label;
  final String? selectedProvince;
  final String? selectedCity;
  final ValueChanged<String> onProvinceChanged;
  final ValueChanged<String> onCityChanged;

  const RegionSelectorWidget({
    super.key,
    required this.label,
    this.selectedProvince,
    this.selectedCity,
    required this.onProvinceChanged,
    required this.onCityChanged,
  });

  @override
  State<RegionSelectorWidget> createState() => _RegionSelectorWidgetState();
}

class _RegionSelectorWidgetState extends State<RegionSelectorWidget> {
  String? _province;
  String? _city;

  @override
  void initState() {
    super.initState();
    _province = widget.selectedProvince;
    _city = widget.selectedCity;
    // 도가 없고 도시만 있으면 도 자동 추론
    if (_province == null && _city != null) {
      _province = getProvinceOfCity(_city!) ?? _province;
    }
  }

  @override
  void didUpdateWidget(RegionSelectorWidget old) {
    super.didUpdateWidget(old);
    if (widget.selectedProvince != old.selectedProvince) {
      _province = widget.selectedProvince;
    }
    if (widget.selectedCity != old.selectedCity) {
      _city = widget.selectedCity;
      if (_province == null && _city != null) {
        _province = getProvinceOfCity(_city!);
      }
    }
  }

  InputDecoration _inputDeco({String? hint}) => InputDecoration(
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final provinces = getProvinces();
    final cities =
        _province != null ? getCitiesInProvince(_province!) : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // 도/광역시 선택
        DropdownButtonFormField<String>(
          initialValue: _province,
          hint: const Text('도 / 광역시 선택'),
          decoration: _inputDeco(),
          isExpanded: true,
          items: provinces
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _province = v;
              _city = null;
            });
            widget.onProvinceChanged(v);
          },
        ),

        // 시/군 선택 (도 선택 후 표시)
        if (_province != null && cities.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: (_city != null && cities.contains(_city)) ? _city : null,
            hint: const Text('시 / 군 선택'),
            decoration: _inputDeco(),
            isExpanded: true,
            items: cities
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _city = v);
              widget.onCityChanged(v);
            },
          ),
        ],

        // 선택된 최적 역 미리보기
        if (_city != null) ...[
          const SizedBox(height: 6),
          Builder(builder: (_) {
            final best = getBestStation(_city!);
            if (best == null) return const SizedBox.shrink();
            return Row(
              children: [
                const Icon(Icons.train_outlined,
                    size: 13, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '자동 선택: $best',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            );
          }),
        ],
      ],
    );
  }
}
