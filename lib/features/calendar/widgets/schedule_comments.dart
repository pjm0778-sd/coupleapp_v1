import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../shared/models/schedule_comment.dart';

class ScheduleCommentsWidget extends StatelessWidget {
  final List<ScheduleComment> comments;
  final String? currentUserId;

  const ScheduleCommentsWidget({
    super.key,
    required this.comments,
    this.currentUserId,
  });

  bool _isMine(ScheduleComment comment) {
    return currentUserId != null && comment.userId == currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return _EmptyState(message: '댓글이 없어요', icon: Icons.chat_bubble_outline);
    }

    return Column(
      children: [
        // 댓글 수 표시
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '댓글 (${comments.length})',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const Divider(height: 1),
        // 댓글 목록
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, _) => const SizedBox(height: 1),
            itemCount: comments.length,
            itemBuilder: (context, index) {
              final comment = comments[index];
              final isMine = _isMine(comment);
              return _CommentItem(
                comment: comment,
                isMine: isMine,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CommentItem extends StatelessWidget {
  final ScheduleComment comment;
  final bool isMine;

  const _CommentItem({
    required this.comment,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아바타
          _Avatar(
            initial: comment.content.isNotEmpty ? comment.content[0].toUpperCase() : '?',
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
          if (isMine)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              onPressed: () {
                // 부모 위젯에서 처리
              },
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

class _Avatar extends StatelessWidget {
  final String initial;

  const _Avatar({
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const _EmptyState({
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: AppTheme.textSecondary.withOpacity(0.4),
            size: 32,
          ),
          const SizedBox(width: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
