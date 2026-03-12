import '../../../core/supabase_client.dart';
import '../../../shared/models/schedule_comment.dart';

class CommentService {
  /// 일정 댓글 조회
  Future<List<ScheduleComment>> getComments(String scheduleId) async {
    final data = await supabase
        .from('schedule_comments')
        .select('*')
        .eq('schedule_id', scheduleId)
        .order('created_at', ascending: true);

    return (data as List)
        .map((e) => ScheduleComment.fromMap(e))
        .toList();
  }

  /// 일정 댓글 실시간 스트림 (Realtime 자동 구독)
  Stream<List<ScheduleComment>> subscribeToComments(String scheduleId) {
    return supabase
        .from('schedule_comments')
        .stream(primaryKey: ['id'])
        .eq('schedule_id', scheduleId)
        .order('created_at', ascending: true)
        .map((dataList) {
          // List<Map<String, dynamic>>를 List<ScheduleComment>로 변환
          return (dataList as List)
              .map((e) => ScheduleComment.fromMap(e))
              .toList();
        });
  }

  /// 댓글 추가
  Future<void> addComment(
    String scheduleId,
    String content,
  ) async {
    await supabase.from('schedule_comments').insert({
      'schedule_id': scheduleId,
      'user_id': supabase.auth.currentUser!.id,
      'content': content,
    });
  }

  /// 댓글 삭제
  Future<void> deleteComment(String id) async {
    await supabase.from('schedule_comments').delete().eq('id', id);
  }

  /// 댓글이 현재 유저의 것인지 확인
  bool isMine(ScheduleComment comment) =>
      comment.userId == supabase.auth.currentUser!.id;
}
