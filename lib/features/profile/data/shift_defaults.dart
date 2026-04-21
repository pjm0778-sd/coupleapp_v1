import '../models/shift_time.dart';

/// 근무 패턴별 기본 ShiftTime 목록
/// D: 06~15 / E: 13~22 / N: 20~08(익일) / M: 09~17
const Map<String, List<Map<String, dynamic>>> _shiftDefaultMaps = {
  'shift_3': [
    {
      'shift_type': 'D',
      'label': 'D',
      'color_hex': '#4CAF50',
      'start_h': 6,
      'start_m': 0,
      'end_h': 15,
      'end_m': 0,
      'is_next_day': false,
    },
    {
      'shift_type': 'E',
      'label': 'E',
      'color_hex': '#2196F3',
      'start_h': 13,
      'start_m': 0,
      'end_h': 22,
      'end_m': 0,
      'is_next_day': false,
    },
    {
      'shift_type': 'M',
      'label': 'M',
      'color_hex': '#FF9800',
      'start_h': 9,
      'start_m': 0,
      'end_h': 17,
      'end_m': 0,
      'is_next_day': false,
    },
    {
      'shift_type': 'N',
      'label': 'N',
      'color_hex': '#7E57C2',
      'start_h': 20,
      'start_m': 0,
      'end_h': 8,
      'end_m': 0,
      'is_next_day': true,
    },
  ],
  'shift_2': [
    {
      'shift_type': 'day',
      'label': 'day',
      'color_hex': '#26A69A',
      'start_h': 7,
      'start_m': 0,
      'end_h': 19,
      'end_m': 0,
      'is_next_day': false,
    },
    {
      'shift_type': 'night',
      'label': 'night',
      'color_hex': '#5C6BC0',
      'start_h': 19,
      'start_m': 0,
      'end_h': 7,
      'end_m': 0,
      'is_next_day': true,
    },
  ],
  'office': [
    {
      'shift_type': 'office',
      'label': 'office',
      'color_hex': '#43A047',
      'start_h': 9,
      'start_m': 0,
      'end_h': 18,
      'end_m': 0,
      'is_next_day': false,
    },
  ],
  'other': [
    {
      'shift_type': 'work',
      'label': 'work',
      'color_hex': '#00897B',
      'start_h': 9,
      'start_m': 0,
      'end_h': 18,
      'end_m': 0,
      'is_next_day': false,
    },
  ],
};

/// 패턴명으로 기본 ShiftTime 목록 반환 (타입드)
List<ShiftTime> getShiftDefaults(String pattern) {
  final maps = _shiftDefaultMaps[pattern] ?? [];
  return maps.map(ShiftTime.fromMap).toList();
}

/// 하위 호환: 기존 코드가 Map 형식으로 접근하는 경우를 위한 getter
/// ShiftTimeEditor 등 내부 Map 접근 코드는 ShiftTime.toMap() 을 통해 변환
Map<String, List<Map<String, dynamic>>> get shiftDefaults => _shiftDefaultMaps;

String shiftLabel(String pattern) {
  switch (pattern) {
    case 'shift_3':
      return '교대근무 3교대';
    case 'shift_2':
      return '교대 근무 2교대';
    case 'office':
      return '일반 직장인 (주5일)';
    case 'other':
      return '기타 / 프리랜서';
    default:
      return pattern;
  }
}
