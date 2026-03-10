import '../../../core/supabase_client.dart';
import '../../../shared/models/anniversary_setting.dart';

class AnniversaryService {
  /// 커플 기념일 조회
  Future<List<AnniversarySetting>> getAnniversaries(String coupleId) async {
    final data = await supabase
        .from('anniversary_settings')
        .select()
        .eq('couple_id', coupleId)
        .eq('is_enabled', true)
        .order('created_at', ascending: true);

    return (data as List)
        .map((e) => AnniversarySetting.fromMap(e))
        .toList();
  }

  /// 기념일 추가
  Future<void> addAnniversary(AnniversarySetting anniversary) async {
    await supabase.from('anniversary_settings').insert(anniversary.toMap());
  }

  /// 기념일 수정
  Future<void> updateAnniversary(
    String id,
    Map<String, dynamic> data,
  ) async {
    await supabase.from('anniversary_settings').update(data).eq('id', id);
  }

  /// 기념일 삭제
  Future<void> deleteAnniversary(String id) async {
    await supabase.from('anniversary_settings').delete().eq('id', id);
  }

  /// 기념일 토글 (활성/비활성)
  Future<void> toggleAnniversary(String id, bool isEnabled) async {
    await supabase
        .from('anniversary_settings')
        .update({'is_enabled': isEnabled})
        .eq('id', id);
  }

  /// 해당 연도/월의 기념일 날짜 목록 조회
  Future<List<DateTime>> getAnniversaryDates(
    String coupleId,
    int year,
    int month,
  ) async {
    final settings = await getAnniversaries(coupleId);
    final dates = <DateTime>[];

    for (final setting in settings) {
      final date = setting.getDateForYear(year);
      if (date != null && date.month == month) {
        dates.add(date);
      }
    }

    dates.sort((a, b) => a.compareTo(b));
    return dates;
  }
}
