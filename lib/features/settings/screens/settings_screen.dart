import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../notifications/screens/notification_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _myNickname;
  String? _partnerNickname;
  DateTime? _startedAt;
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  String? _coupleId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면이 다시 열릴 때 데이터 갱신 (커플 연결 후)
    if (_hasLoadedOnce) {
      _loadData();
    }
    _hasLoadedOnce = true;
  }

  Future<void> _changeStartedAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startedAt ?? DateTime(2020, 1, 1),
      firstDate: DateTime(2000),
      lastDate: now,
    );

    if (date != null && _coupleId != null) {
      try {
        await supabase
            .from('couples')
            .update({'started_at': date.toIso8601String().split('T')[0]})
            .eq('id', _coupleId!);
        if (mounted) {
          setState(() => _startedAt = date);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('연애 시작일이 변경되었습니다')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('변경 실패: $e')),
          );
        }
      }
    }
  }

  Future<void> _loadData() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      // 내 프로필
      final profile = await supabase
          .from('profiles')
          .select('nickname, couple_id')
          .eq('id', userId)
          .single();
      _myNickname = profile['nickname'] as String?;
      final coupleId = profile['couple_id'] as String?;

      // 커플 정보
      if (coupleId != null) {
        _coupleId = coupleId;
        final couple = await supabase
            .from('couples')
            .select('started_at, user1_id, user2_id')
            .eq('id', coupleId)
            .maybeSingle();
        if (couple == null) {
          _partnerNickname = null;
          _startedAt = null;
        } else {
          _startedAt = DateTime.parse(couple['started_at'] as String);
          final partnerId = couple['user1_id'] == userId
              ? couple['user2_id']
              : couple['user1_id'];
          if (partnerId != null && partnerId!.isNotEmpty) {
            final partner = await supabase
                .from('profiles')
                .select('nickname')
                .eq('id', partnerId)
                .maybeSingle();
            _partnerNickname = partner?['nickname'] as String?;
          } else {
            _partnerNickname = null;
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('로그아웃', style: TextStyle(fontSize: 16)),
        content: const Text('로그아웃 하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirm == true) await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                // 커플 정보 섹션
                _buildSectionTitle('커플 정보'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 닉네임 & 파트너
                      Row(
                        children: [
                          const Icon(Icons.favorite,
                              color: AppTheme.accent, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            _myNickname ?? '-',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('&',
                                style: TextStyle(color: AppTheme.textSecondary)),
                          ),
                          Text(
                            _partnerNickname ?? '연결 대기 중',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: _partnerNickname != null
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _coupleId != null ? _changeStartedAt : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _startedAt != null
                                      ? 'D+${DateTime.now().difference(_startedAt!).inDays + 1}'
                                      : '날짜 설정',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: _startedAt != null
                                          ? AppTheme.primary
                                          : AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.edit_outlined,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 연애 시작일
                      GestureDetector(
                        onTap: _coupleId != null ? _changeStartedAt : null,
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _startedAt != null
                                  ? '연애 시작일: ${_startedAt!.year}년 ${_startedAt!.month}월 ${_startedAt!.day}일'
                                  : '연애 시작일: 미설정 (탭하여 설정)',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 20),

                // 알림 설정
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    foregroundColor: AppTheme.textPrimary,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_outlined, size: 18),
                  label: const Text('알림 설정',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                ),

                const SizedBox(height: 20),

                // 로그아웃
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    foregroundColor: Colors.redAccent,
                  ),
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('로그아웃',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary),
    );
  }
}
