import '../../../core/supabase_client.dart';
import '../../core/models/user_settings.dart';
import '../../core/models/shift_type.dart';

class UserSettingsService {
  static final UserSettingsService _instance = UserSettingsService._internal();
  factory UserSettingsService() => _instance;
  UserSettingsService._internal();

  Future<UserSettings?> getUserSettings(String userId) async {
    final data = await supabase
        .from('user_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return null;
    return UserSettings.fromJson(data);
  }

  Future<void> upsertUserSettings({
    required String userId,
    required ShiftType shiftType,
    required String defaultShift,
  }) async {
    final existing = await getUserSettings(userId);

    if (existing != null) {
      // 새로 생성
      await supabase.from('user_settings').insert({
        'user_id': userId,
        'shift_type': shiftType.value,
        'default_shift': defaultShift,
      });
    } else {
      // 업데이트
      await supabase
          .from('user_settings')
          .update({
            'shift_type': shiftType.value,
            'default_shift': defaultShift,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', existing!.id);
    }
  }

  Future<ShiftType> getShiftType(String userId) async {
    final settings = await getUserSettings(userId);
    return settings?.shiftType ?? ShiftType.regularOffice;
  }

  Future<String> getDefaultShift(String userId) async {
    final settings = await getUserSettings(userId);
    return settings?.defaultShift ?? '주간근무';
  }
}
