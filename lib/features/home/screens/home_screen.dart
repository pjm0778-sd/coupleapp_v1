import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String? _myNickname;
  String? _partnerNickname;
  DateTime? _startedAt;
  String? _coupleId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      // 내 프로필 + couple_id
      final profile = await supabase
          .from('profiles')
          .select('nickname, couple_id')
          .eq('id', userId)
          .single();

      _myNickname = profile['nickname'] as String?;
      _coupleId = profile['couple_id'] as String?;

      if (_coupleId != null) {
        // 커플 정보 (사귄 날짜)
        final couple = await supabase
            .from('couples')
            .select('started_at, user1_id, user2_id')
            .eq('id', _coupleId!)
            .single();

        _startedAt = DateTime.parse(couple['started_at'] as String);

        // 파트너 ID
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

  int get _dday {
    if (_startedAt == null) return 0;
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final start =
        DateTime(_startedAt!.year, _startedAt!.month, _startedAt!.day);
    return today.difference(start).inDays + 1;
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

  Future<void> _pickStartDate() async {
    if (_coupleId == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _startedAt ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: '사귄 날짜 선택',
    );
    if (picked == null) return;
    await supabase
        .from('couples')
        .update({'started_at': picked.toIso8601String().split('T')[0]})
        .eq('id', _coupleId!);
    setState(() => _startedAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('우리의 하루'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _isLoading = true);
                await _loadData();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDDayCard(),
                    const SizedBox(height: 20),
                    _buildUpcomingSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDDayCard() {
    return GestureDetector(
      onTap: _pickStartDate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // 커플 이름
            if (_myNickname != null || _partnerNickname != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _myNickname ?? '',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.favorite,
                          color: AppTheme.accent, size: 16),
                    ),
                    Text(
                      _partnerNickname ?? '연결 대기 중',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

            const Text(
              '우리가 함께한 날',
              style: TextStyle(
                  color: Colors.white60, fontSize: 14, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),
            Text(
              _startedAt != null ? 'D + $_dday' : 'D + ?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 54,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _startedAt != null
                  ? '${_formatDate(_startedAt!)} ~'
                  : '탭해서 시작일 설정',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '다가오는 일정',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Column(
            children: [
              Icon(Icons.calendar_today_outlined,
                  color: AppTheme.textSecondary, size: 28),
              SizedBox(height: 10),
              Text(
                '등록된 일정이 없어요',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
