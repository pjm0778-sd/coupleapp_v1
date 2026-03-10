import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/schedule.dart';
import '../../../shared/models/schedule_comment.dart';
import '../services/schedule_service.dart';
import '../services/comment_service.dart';

class ScheduleDetailScreen extends StatefulWidget {
  final Schedule schedule;

  const ScheduleDetailScreen({
    super.key,
    required this.schedule,
  });

  @override
  State<ScheduleDetailScreen> createState() => _ScheduleDetailScreenState();
}

class _ScheduleDetailScreenState extends State<ScheduleDetailScreen> {
  final _scheduleService = ScheduleService();
  final _commentService = CommentService();

  List<ScheduleComment> _comments = [];
  bool _isLoadingComments = true;
  bool _isDeleting = false;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);
    try {
      final comments = await _commentService.getComments(widget.schedule.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingComments = false);
      }
    }
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    try {
      await _commentService.addComment(widget.schedule.id, content);
      _commentController.clear();
      await _loadComments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 추가 실패')),
      );
    }
  }

  Future<void> _deleteComment(String id) async {
    try {
      await _commentService.deleteComment(id);
      await _loadComments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 삭제 실패')),
      );
    }
  }

  Future<void> _deleteSchedule() async {
    setState(() => _isDeleting = true);
    try {
      await _scheduleService.deleteSchedule(widget.schedule.id);
      if (mounted) {
        Navigator.pop(context, true); // true = deleted
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정 삭제 실패')),
      );
    }
  }

  bool get _isMine => _scheduleService.isMine(widget.schedule);

  @override
  Widget build(BuildContext context) {
    final title = widget.schedule.title ?? widget.schedule.workType ?? '일정';
    final category = widget.schedule.category;
    final categoryColor = _getCategoryColor(category);
    final categoryIcon = _getCategoryIcon(category);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_isMine && !_isDeleting)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteSchedule(),
              tooltip: '삭제',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildInfoCard(category, categoryColor, categoryIcon),
          const Divider(height: 1),
          Expanded(
            child: _buildCommentsSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String? category, Color categoryColor, IconData categoryIcon) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카테고리
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: categoryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  categoryIcon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.schedule.title ?? widget.schedule.workType ?? '일정',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (category != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        category!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 날짜/시간
          _buildInfoRow(Icons.calendar_today_outlined,
              '${_formatDate(widget.schedule.date)}'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.access_time, _formatTimeRange()),
          const SizedBox(height: 16),
          // 장소
          if (widget.schedule.location != null && widget.schedule.location!.isNotEmpty)
            _buildInfoRow(Icons.location_on_outlined, widget.schedule.location!),
          if (widget.schedule.location != null && widget.schedule.location!.isNotEmpty)
            const SizedBox(height: 8),
          // 메모
          if (widget.schedule.note != null && widget.schedule.note!.isNotEmpty)
            _buildInfoRow(Icons.note_outlined, widget.schedule.note!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '댓글 (${_comments.length})',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoadingComments
              ? const Center(child: CircularProgressIndicator())
              : _comments.isEmpty
                  ? _EmptyState(
                      message: '댓글이 없어요',
                      icon: Icons.chat_bubble_outline,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _comments.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        final isMine = _commentService.isMine(comment);
                        return _CommentItem(
                          comment: comment,
                          isMine: isMine,
                          onDelete: isMine ? () => _deleteComment(comment.id) : null,
                        );
                      },
                    ),
        ),
        // 댓글 입력
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: '댓글을 입력하세요...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
                    ),
                    style: TextStyle(color: AppTheme.textPrimary),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _addComment,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.year}년 ${date.month}월 ${date.day}일 (${weekdays[date.weekday - 1]})';
  }

  String _formatTimeRange() {
    if (widget.schedule.startTime == null && widget.schedule.endTime == null) {
      return '';
    }
    final start = _formatTime(widget.schedule.startTime);
    final end = _formatTime(widget.schedule.endTime);
    if (end.isEmpty) return start;
    return '$start ~ $end';
  }

  String _formatTime(var time) {
    if (time == null) return '';
    if (time is TimeOfDay) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return time.toString();
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case '근무':
        return const Color(0xFF4CAF50);
      case '약속':
        return const Color(0xFF2196F3);
      case '여행':
        return const Color(0xFFFF9800);
      case '데이트':
        return const Color(0xFFE91E63);
      case '휴무':
        return const Color(0xFFBDBDBD);
      default:
        return AppTheme.primary;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case '근무':
        return Icons.work_outline;
      case '약속':
        return Icons.handshake_outlined;
      case '여행':
        return Icons.flight_takeoff_outlined;
      case '데이트':
        return Icons.favorite_outline;
      case '휴무':
        return Icons.beach_access_outlined;
      default:
        return Icons.event_outlined;
    }
  }
}

class _CommentItem extends StatelessWidget {
  final ScheduleComment comment;
  final bool isMine;
  final VoidCallback? onDelete;

  const _CommentItem({
    super.key,
    required this.comment,
    required this.isMine,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아바타 (간단히 원형)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                comment.content[0].toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 댓글 내용
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(comment.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // 삭제 버튼 (내 댓글만)
          if (isMine && onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              onPressed: onDelete,
              style: IconButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
              ),
              tooltip: '삭제',
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return '방금';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}분 전';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}시간 전';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }
}
