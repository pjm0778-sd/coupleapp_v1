import '../../features/profile/models/couple_profile.dart';
import '../../features/profile/models/shift_time.dart';

/// 커플 프로필 설정값 기반 기능 활성화 싱글톤
class FeatureFlagService {
  static final FeatureFlagService _instance = FeatureFlagService._();
  factory FeatureFlagService() => _instance;
  FeatureFlagService._();

  CoupleProfile? _profile;

  void refresh(CoupleProfile profile) => _profile = profile;

  void clear() => _profile = null;

  /// D-day 및 기념일 알림
  bool get isDdayEnabled => true; // couples.started_at 항상 존재

  /// 교통편 추천 (장거리 + 역 설정 완료 시)
  bool get isTransportEnabled => _profile?.hasTransportInfo ?? false;

  /// OCR 근무시간 자동기입 (교대근무 + 시프트 시간 설정 시)
  bool get isOcrAutoTimeEnabled =>
      (_profile?.hasShiftWork ?? false) &&
      (_profile?.shiftTimes.isNotEmpty ?? false);

  /// 출퇴근 알림
  bool get isCommuteAlertEnabled => _profile?.shiftTimes.isNotEmpty ?? false;

  /// 밤번 후 방해금지 자동 ON
  bool get isNightShiftDndEnabled => _profile?.hasNightShift ?? false;

  /// 파트너 근무 상태 표시
  /// [GAP-FIX] coupleId != null (파트너 연결됨) 조건 추가
  bool get isPartnerStatusEnabled =>
      (_profile?.isConnected ?? false) &&
      (_profile?.hasShiftWork ?? false);

  /// 장거리 방문 순서 기록
  bool get isVisitTrackingEnabled => _profile?.isLongDistance ?? false;

  /// 자차 교통 옵션
  bool get isCarOptionEnabled => _profile?.hasCar ?? false;

  /// 현재 프로필 (읽기 전용)
  CoupleProfile? get profile => _profile;

  /// 출근 알림 N분 전
  int get notifyMinutesBefore => _profile?.notifyMinutesBefore ?? 30;

  /// 시프트 타입으로 ShiftTime 조회 (OCR 자동기입용)
  /// [GAP-FIX] Map 대신 타입드 ShiftTime? 반환
  ShiftTime? getShiftTime(String shiftType) {
    if (_profile == null) return null;
    try {
      return _profile!.shiftTimes.firstWhere(
        (s) => s.shiftType == shiftType,
      );
    } catch (_) {
      return null;
    }
  }
}
