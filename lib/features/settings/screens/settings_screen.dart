import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/color_mapping.dart';
import '../../notifications/screens/notification_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<ColorMapping> _mappings = [];
  String? _myNickname;
  String? _partnerNickname;
  DateTime? _startedAt;
  bool _isLoading = true;

  static const List<Color> _presetColors = AppTheme.scheduleColors;

  @override
  void initState() {
    super.initState();
    _loadData();
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

      // 색상 매핑
      final mappings = await supabase
          .from('color_mappings')
          .select()
          .eq('user_id', userId);
      _mappings = (mappings as List).map((e) => ColorMapping.fromMap(e)).toList();

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

  Color _hexToColor(String hex) {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  }

  String _colorToHex(Color color) {
    final r = color.r.round().toRadixString(16).padLeft(2, '0');
    final g = color.g.round().toRadixString(16).padLeft(2, '0');
    final b = color.b.round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  Future<void> _deleteMapping(ColorMapping m, int index) async {
    await supabase.from('color_mappings').delete().eq('id', m.id);
    setState(() => _mappings.removeAt(index));
  }

  void _showAddDialog() {
    String workType = '';
    Color selectedColor = _presetColors.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('색상 매핑 추가',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('색상 선택',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetColors.map((color) {
                  final isSelected =
                      selectedColor.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () => setDialog(() => selectedColor = color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: AppTheme.primary, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('근무 형태',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                autofocus: true,
                onChanged: (v) => workType = v,
                decoration: InputDecoration(
                  hintText: '예) 휴무, 나이트, 데이...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (workType.trim().isEmpty) return;
                final userId = supabase.auth.currentUser!.id;
                final hex = _colorToHex(selectedColor);
                final result = await supabase
                    .from('color_mappings')
                    .insert({'user_id': userId, 'color_hex': hex, 'work_type': workType.trim()})
                    .select()
                    .single();
                setState(() => _mappings.add(ColorMapping.fromMap(result)));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
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

                const SizedBox(height: 28),

                // 색상 매핑 섹션
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('색상 - 근무 형태 매핑'),
                          const SizedBox(height: 2),
                          const Text(
                            '스케줄 이미지의 색상과 근무 형태를 연결하세요',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: _mappings.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(28),
                          child: Center(
                            child: Text(
                              '아래 버튼으로 매핑을 추가하세요',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ),
                        )
                      : Column(
                          children: _mappings.asMap().entries.map((entry) {
                            final i = entry.key;
                            final m = entry.value;
                            return Column(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  leading: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: _hexToColor(m.colorHex),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  title: Text(m.workType,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15)),
                                  subtitle: Text(m.colorHex,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: AppTheme.textSecondary, size: 20),
                                    onPressed: () => _deleteMapping(m, i),
                                  ),
                                ),
                                if (i < _mappings.length - 1)
                                  const Divider(
                                      height: 1, indent: 64, endIndent: 16),
                              ],
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    foregroundColor: AppTheme.textPrimary,
                  ),
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('매핑 추가',
                      style: TextStyle(fontWeight: FontWeight.w500)),
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
