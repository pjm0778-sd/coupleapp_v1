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
    // ?붾㈃???ㅼ떆 ?대┫ ???곗씠??媛깆떊 (而ㅽ뵆 ?곌껐 ??
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
            const SnackBar(content: Text('?곗븷 ?쒖옉?쇱씠 蹂寃쎈릺?덉뒿?덈떎')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('蹂寃??ㅽ뙣: $e')),
          );
        }
      }
    }
  }

  Future<void> _editProfile(bool isMyProfile) async {
    final controller = TextEditingController(
        text: isMyProfile ? _myNickname : _partnerNickname);
        
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isMyProfile ? '???대쫫 蹂寃? : '?좎씤 ?대쫫 ?ㅼ젙'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '?대쫫???낅젰?섏꽭??),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('痍⑥냼'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('???),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      try {
        final userId = supabase.auth.currentUser!.id;
        
        if (isMyProfile) {
          await supabase
              .from('profiles')
              .update({'nickname': newName})
              .eq('id', userId);
          setState(() => _myNickname = newName);
        } else {
          // ?좎씤 ?대쫫? ?뚰듃?덉쓽 ?ㅼ젣 ?꾨줈?꾩쓣 諛붽씀??寃껋씠 ?꾨땲??
          // ?꾩옱 ?좎???profile ?뚯씠釉?(ex: partner_nickname_override ?꾨뱶 ??????ν븯???뺥깭媛 ?댁긽?곸씠吏留? 
          // ?꾩옱 DB 援ъ“???뚰듃?덉쓽 ?됰꽕?꾩쓣 吏곸젒 ?섏젙 沅뚰븳???덈떎硫??섏젙?섍굅??
          // ???댁뿉??怨좎젙?곸쑝濡?'???좎씤'?쇰줈 ?쒖떆?섎뒗寃??붽뎄?ы빆???쇰??대?濡? ?꾩떆濡?吏곸젒 ?낅뜲?댄듃
          // 留뚯빟 沅뚰븳???녿떎硫?RLS ?먮윭媛 ?????덉쓬.
          if (_coupleId != null) {
            final couple = await supabase
              .from('couples')
              .select('user1_id, user2_id')
              .eq('id', _coupleId!)
              .single();
            final partnerId = couple['user1_id'] == userId ? couple['user2_id'] : couple['user1_id'];
            if (partnerId != null) {
               await supabase
                .from('profiles')
                .update({'nickname': newName})
                .eq('id', partnerId);
               setState(() => _partnerNickname = newName);
            }
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('?대쫫??蹂寃쎈릺?덉뒿?덈떎')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('蹂寃??ㅽ뙣: $e')),
          );
        }
      }
    }
  }

  Future<void> _loadData() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      // ???꾨줈??
      final profile = await supabase
          .from('profiles')
          .select('nickname, couple_id')
          .eq('id', userId)
          .single();
      _myNickname = profile['nickname'] as String?;
      final coupleId = profile['couple_id'] as String?;

      // 而ㅽ뵆 ?뺣낫
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
        title: const Text('濡쒓렇?꾩썐', style: TextStyle(fontSize: 16)),
        content: const Text('濡쒓렇?꾩썐 ?섏떆寃좎뼱??'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('痍⑥냼', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('濡쒓렇?꾩썐'),
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
        title: const Text('?ㅼ젙'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
            tooltip: '?덈줈怨좎묠',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                // 而ㅽ뵆 ?뺣낫 ?뱀뀡
                _buildSectionTitle('而ㅽ뵆 ?뺣낫'),
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
                      // ?됰꽕??& ?뚰듃??
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
                            _partnerNickname ?? '?곌껐 ?湲?以?,
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
                                      : '?좎쭨 ?ㅼ젙',
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
                      // ?곗븷 ?쒖옉??
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
                                  ? '?곗븷 ?쒖옉?? ${_startedAt!.year}??${_startedAt!.month}??${_startedAt!.day}??
                                  : '?곗븷 ?쒖옉?? 誘몄꽕??(??븯???ㅼ젙)',
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
                
                // ???꾨줈???ㅼ젙 (?대쫫 蹂寃?
                _buildSectionTitle('?꾨줈???ㅼ젙'),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline, color: AppTheme.textPrimary),
                        title: const Text('???대쫫 蹂寃?),
                        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                        onTap: () => _editProfile(true),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.favorite_border, color: AppTheme.accent),
                        title: const Text('?좎씤 ?대쫫 ?ㅼ젙'),
                        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                        onTap: () => _editProfile(false),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),

                // ???ㅼ젙
                _buildSectionTitle('???ㅼ젙'),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.notifications_outlined, color: AppTheme.textPrimary),
                        title: const Text('?뚮┝ ?ㅼ젙'),
                        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationSettingsScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.info_outline, color: AppTheme.textPrimary),
                        title: const Text('??踰꾩쟾'),
                        trailing: const Text('v1.0.0', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.description_outlined, color: AppTheme.textPrimary),
                        title: const Text('?쒕퉬???댁슜?쎄?'),
                        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                        onTap: () {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('以鍮?以묒엯?덈떎.')));
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined, color: AppTheme.textPrimary),
                        title: const Text('媛쒖씤?뺣낫 泥섎━諛⑹묠'),
                        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                        onTap: () {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('以鍮?以묒엯?덈떎.')));
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 濡쒓렇?꾩썐
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
                  label: const Text('濡쒓렇?꾩썐',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                ),
                const SizedBox(height: 16),
                
                // 怨꾩젙 ?덊눜
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('?뚯썝 ?덊눜'),
                        content: const Text('?뺣쭚濡??덊눜?섏떆寃좎뒿?덇퉴? 紐⑤뱺 ?곗씠?곌? ??젣?섎ŉ 蹂듦뎄?????놁뒿?덈떎.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('痍⑥냼')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                            onPressed: () async {
                               // ?덊눜 濡쒖쭅 (?덉떆: Edge Function ?몄텧 ?먮뒗 auth 泥섎━)
                               Navigator.pop(ctx);
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('?덊눜 泥섎━媛 ?꾨즺?섏뿀?듬땲??')));
                               await supabase.auth.signOut();
                            }, 
                            child: const Text('?덊눜?섍린')
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('?뚯썝 ?덊눜', style: TextStyle(color: Colors.grey, decoration: TextDecoration.underline)),
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
