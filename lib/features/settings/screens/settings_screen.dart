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
        final couple = await supabase
            .from('couples')
            .select('started_at, user1_id, user2_id')
            .eq('id', coupleId)
            .single();
        _startedAt = DateTime.parse(couple['started_at'] as String);
        final partnerId = couple['user1_id'] == userId
            ? couple['user2_id']
            : couple['user1_id'];
        if (partnerId != null) {
          final partner = await supabase
              .from('profiles')
              .select('nickname')
              .eq('id', partnerId)
              .maybeSingle();
          _partnerNickname = partner?['nickname'] as String?;
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
      appBar: AppBar(title: const Text('설정')),
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
                  child: Row(
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
                      if (_startedAt != null)
                        Text(
                          'D+${DateTime.now().difference(_startedAt!).inDays + 1}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500),
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
