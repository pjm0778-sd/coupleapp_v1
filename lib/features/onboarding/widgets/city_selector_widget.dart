import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../profile/data/city_station_data.dart';

class CitySelectorWidget extends StatefulWidget {
  final String label;
  final String? selectedCity;
  final String? selectedStation;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String?> onStationChanged;

  const CitySelectorWidget({
    super.key,
    required this.label,
    this.selectedCity,
    this.selectedStation,
    required this.onCityChanged,
    required this.onStationChanged,
  });

  @override
  State<CitySelectorWidget> createState() => _CitySelectorWidgetState();
}

class _CitySelectorWidgetState extends State<CitySelectorWidget> {
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cities = getCities();
    final stations = widget.selectedCity != null
        ? getStations(widget.selectedCity!)
        : <String>[];
    final isCustom = widget.selectedCity == '직접 입력';

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
        // 도시 드롭다운
        DropdownButtonFormField<String>(
          value: widget.selectedCity,
          hint: const Text('도시 선택'),
          decoration: InputDecoration(
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
          ),
          items: cities
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              widget.onCityChanged(v);
              widget.onStationChanged(null);
            }
          },
        ),
        // 직접 입력
        if (isCustom) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _customController,
            decoration: InputDecoration(
              hintText: '역/터미널 이름 입력',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
            ),
            onChanged: widget.onStationChanged,
          ),
        ],
        // 역/터미널 드롭다운 (직접 입력 아닐 때)
        if (!isCustom && stations.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: widget.selectedStation,
            hint: const Text('역 / 터미널 선택'),
            decoration: InputDecoration(
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
            ),
            items: stations
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: widget.onStationChanged,
          ),
        ],
      ],
    );
  }
}
