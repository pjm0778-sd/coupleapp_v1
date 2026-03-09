enum ShiftType {
  regularOffice,     // 일반 평일/직장인
  shift3,            // 3교대 근무
  shift2,            // 2교대 근무
  shift4,            // 4교대 근무
  irregular;         // 일반 비정기

  String get value {
    switch (this) {
      case ShiftType.regularOffice:
        return 'regular_office';
      case ShiftType.shift3:
        return 'shift_3';
      case ShiftType.shift2:
        return 'shift_2';
      case ShiftType.shift4:
        return 'shift_4';
      case ShiftType.irregular:
        return 'irregular';
    }
  }

  String get displayName {
    switch (this) {
      case ShiftType.regularOffice:
        return '일반 평일/직장인';
      case ShiftType.shift3:
        return '3교대 근무';
      case ShiftType.shift2:
        return '2교대 근무';
      case ShiftType.shift4:
        return '4교대 근무';
      case ShiftType.irregular:
        return '일반 비정기';
    }
  }

  static ShiftType fromString(String value) {
    switch (value) {
      case 'regular_office':
        return ShiftType.regularOffice;
      case 'shift_3':
        return ShiftType.shift3;
      case 'shift_2':
        return ShiftType.shift2;
      case 'shift_4':
        return ShiftType.shift4;
      case 'irregular':
        return ShiftType.irregular;
      default:
        return ShiftType.regularOffice;
    }
  }
}
