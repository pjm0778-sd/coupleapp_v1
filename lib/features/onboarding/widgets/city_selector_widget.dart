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
  final _customCityCtrl = TextEditingController();
  final _customStationCtrl = TextEditingController();
  bool _isCustom = false;

  static final _predefined =
      cityStations.keys.where((k) => k != '직접 입력').toSet();

  @override
  void initState() {
    super.initState();
    _initMode(widget.selectedCity, widget.selectedStation);
  }

  @override
  void didUpdateWidget(CitySelectorWidget old) {
    super.didUpdateWidget(old);
    if (!_isCustom && old.selectedCity != widget.selectedCity) {
      _initMode(widget.selectedCity, widget.selectedStation);
    }
  }

  void _initMode(String? city, String? station) {
    if (city != null && city.isNotEmpty && city != '직접 입력' && !_predefined.contains(city)) {
      _isCustom = true;
      _customCityCtrl.text = city;
      // 커스텀 도시의 알려진 역이 없을 경우에만 텍스트 필드에 복원
      if (getStations(city).isEmpty) {
        _customStationCtrl.text = station ?? '';
      }
    } else {
      _isCustom = city == '직접 입력';
      if (!_isCustom) {
        _customCityCtrl.clear();
        _customStationCtrl.clear();
      }
    }
  }

  @override
  void dispose() {
    _customCityCtrl.dispose();
    _customStationCtrl.dispose();
    super.dispose();
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
    // 드롭다운에 표시할 값: 커스텀 모드면 '직접 입력'으로 고정
    final dropdownValue = _isCustom ? '직접 입력' : widget.selectedCity;

    // 미리 정의된 도시 선택 시 역/터미널 목록
    final predefinedStations =
        (!_isCustom && widget.selectedCity != null && widget.selectedCity != '직접 입력')
            ? getStations(widget.selectedCity!)
            : <String>[];

    // 직접 입력 모드에서 입력한 도시명에 알려진 역이 있으면 드롭다운 제공
    final customCityName = _customCityCtrl.text.trim();
    final customKnownStations =
        _isCustom && customCityName.isNotEmpty ? getStations(customCityName) : <String>[];

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
          initialValue: dropdownValue,
          hint: const Text('도시 선택'),
          decoration: _inputDeco(),
          items: getCities()
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            if (v == '직접 입력') {
              setState(() {
                _isCustom = true;
                _customCityCtrl.clear();
                _customStationCtrl.clear();
              });
              widget.onCityChanged('');
              widget.onStationChanged(null);
            } else if (v != null) {
              setState(() => _isCustom = false);
              widget.onCityChanged(v);
              widget.onStationChanged(null);
            }
          },
        ),

        // ── 직접 입력 모드 ──
        if (_isCustom) ...[
          const SizedBox(height: 8),
          // 도시명 텍스트 필드
          TextField(
            controller: _customCityCtrl,
            decoration: _inputDeco(hint: '도시 / 지역명 입력'),
            onChanged: (v) {
              setState(() {}); // 역 목록 갱신을 위해 rebuild
              widget.onCityChanged(v);
              widget.onStationChanged(null); // 도시 바뀌면 역 초기화
            },
          ),
          const SizedBox(height: 8),
          // 입력된 도시명에 알려진 역/터미널이 있으면 드롭다운, 없으면 텍스트 필드
          if (customKnownStations.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: (widget.selectedStation != null &&
                      customKnownStations.contains(widget.selectedStation))
                  ? widget.selectedStation
                  : null,
              hint: const Text('역 / 터미널 선택'),
              decoration: _inputDeco(),
              items: customKnownStations
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: widget.onStationChanged,
            )
          else
            TextField(
              controller: _customStationCtrl,
              decoration: _inputDeco(hint: '역 / 터미널 이름 입력 (선택)'),
              onChanged: (v) => widget.onStationChanged(v.isEmpty ? null : v),
            ),
        ],

        // ── 미리 정의된 도시 선택 시 역/터미널 드롭다운 ──
        if (!_isCustom && predefinedStations.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: widget.selectedStation,
            hint: const Text('역 / 터미널 선택'),
            decoration: _inputDeco(),
            items: predefinedStations
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: widget.onStationChanged,
          ),
        ],
      ],
    );
  }
}
