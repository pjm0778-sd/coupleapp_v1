import 'dart:convert';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/profile_change_notifier.dart';
import '../../../core/services/feature_flag_service.dart';
import '../../../core/theme.dart';
import '../../onboarding/widgets/shift_time_editor.dart';
import '../../profile/data/shift_defaults.dart' show getShiftDefaults;
import '../../profile/models/couple_profile.dart';
import '../../profile/models/shift_time.dart';
import '../../profile/services/profile_service.dart';

class CalendarSettingsScreen extends StatefulWidget {
  const CalendarSettingsScreen({super.key});

  @override
  State<CalendarSettingsScreen> createState() => _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState extends State<CalendarSettingsScreen> {
  static const _userTemplatePrefsKey = 'calendar_user_template_types_v1';

  final _profileService = ProfileService();
  CoupleProfile? _profile;
  CoupleProfile? _savedSnapshot;
  List<_UserTemplateType> _userTemplateTypes = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final profile = await _profileService.loadMyProfile();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_userTemplatePrefsKey);
      final templates = _decodeUserTemplates(raw);

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _savedSnapshot = profile;
        _userTemplateTypes = templates;
        _hasUnsavedChanges = false;
      });
      await _persistUserTemplates();
    } catch (e) {
      debugPrint('CalendarSettings _loadData error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ShiftTime> _normalizeShiftTimes(List<ShiftTime> times) {
    return times
        .map((time) => time.copyWith(label: time.shiftType))
        .toList();
  }

  List<_TemplateExample> get _templateExamples => const [
    _TemplateExample('shift_3', '👩‍⚕️', '교대근무 3교대'),
    _TemplateExample('shift_2', '🔄', '교대 근무 2교대'),
  ];

  List<_UserTemplateType> _decodeUserTemplates(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_UserTemplateType.fromMap)
          .where((t) => t.name != '일반 직장인 (주5일)')
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistUserTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _userTemplateTypes.map((e) => e.toMap()).toList(),
    );
    await prefs.setString(_userTemplatePrefsKey, encoded);
  }

  String _nextTemplateName(String base) {
    final names = _userTemplateTypes.map((e) => e.name).toSet();
    if (!names.contains(base)) return base;
    var i = 2;
    while (names.contains('$base $i')) {
      i++;
    }
    return '$base $i';
  }

  Future<void> _createTemplateFromCurrent() async {
    if (_profile == null) return;

    final controller = TextEditingController(
      text: _nextTemplateName('내 템플릿'),
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('템플릿 유형 추가'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '템플릿 이름'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('추가'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final template = _UserTemplateType(
      id: 'tpl_${DateTime.now().microsecondsSinceEpoch}',
      name: _nextTemplateName(name),
      shiftTimes: const [],
    );

    setState(() {
      _userTemplateTypes = [..._userTemplateTypes, template];
    });
    await _persistUserTemplates();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${template.name}" 템플릿을 추가했습니다.')),
    );
  }

  Future<void> _renameUserTemplate(_UserTemplateType template) async {
    final controller = TextEditingController(text: template.name);
    final updatedName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('템플릿 이름 수정'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '새 템플릿 이름'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (updatedName == null || updatedName.isEmpty) return;

    setState(() {
      _userTemplateTypes = _userTemplateTypes
          .map(
            (e) => e.id == template.id ? e.copyWith(name: _nextTemplateName(updatedName)) : e,
          )
          .toList();
    });
    await _persistUserTemplates();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('템플릿 이름을 수정했습니다.')),
    );
  }

  Future<void> _deleteUserTemplate(_UserTemplateType template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('템플릿 삭제'),
        content: Text('"${template.name}" 템플릿을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _userTemplateTypes =
          _userTemplateTypes.where((e) => e.id != template.id).toList();
    });
    await _persistUserTemplates();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('템플릿을 삭제했습니다.')),
    );
  }

  Future<void> _useUserTemplate(_UserTemplateType template) async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(
      shiftTimes: _normalizeShiftTimes(template.shiftTimes),
    );
    _setDraftProfile(updated);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${template.name}" 템플릿을 적용했습니다.')),
    );
  }

  Future<void> _useExampleTemplate(_TemplateExample example) async {
    final template = _UserTemplateType(
      id: 'tpl_${DateTime.now().microsecondsSinceEpoch}',
      name: _nextTemplateName(example.name),
      shiftTimes: _normalizeShiftTimes(getShiftDefaults(example.pattern)),
    );

    setState(() {
      _userTemplateTypes = [..._userTemplateTypes, template];
    });
    await _persistUserTemplates();
    if (!mounted) return;
    await _useUserTemplate(template);
  }

  void _setDraftProfile(CoupleProfile next) {
    final saved = _savedSnapshot;
    final changed = saved == null
        ? true
        : !listEquals(next.shiftTimes, saved.shiftTimes);
    setState(() {
      _profile = next;
      _hasUnsavedChanges = changed;
    });
  }

  Future<bool> _confirmExitIfNeeded() async {
    if (!_hasUnsavedChanges) return true;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('저장하지 않고 나갈까요?'),
        content: const Text('저장하지 않은 변경사항은 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('계속 편집'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('저장 안 함'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('저장 후 나가기'),
          ),
        ],
      ),
    );

    if (action == 'save') {
      return _saveChanges(showSuccessMessage: false);
    }
    return action == 'discard';
  }

  Future<void> _onBackPressed() async {
    final canPop = await _confirmExitIfNeeded();
    if (!canPop || !mounted) return;
    Navigator.pop(context);
  }

  Future<bool> _saveChanges({bool showSuccessMessage = true}) async {
    if (_profile == null) return true;
    if (!_hasUnsavedChanges) return true;
    if (_isSaving) return false;

    setState(() => _isSaving = true);
    try {
      final normalized = _normalizeShiftTimes(_profile!.shiftTimes);
      final profileToSave = _profile!.copyWith(
        workPattern: 'other',
        shiftTimes: normalized,
      );

      await _profileService.saveProfile(profileToSave);
      FeatureFlagService().refresh(profileToSave);
      ProfileChangeNotifier().notify();

      if (!mounted) return true;
      setState(() {
        _profile = profileToSave;
        _savedSnapshot = profileToSave;
        _hasUnsavedChanges = false;
      });
      if (showSuccessMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('달력 설정이 저장되었습니다.')),
        );
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showWorkPatternPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetContext, sheetSetState) => SafeArea(
          child: DefaultTabController(
            length: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: SizedBox(
                height: 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '템플릿 유형 선택',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    const TabBar(
                      tabs: [
                        Tab(text: '내 템플릿'),
                        Tab(text: '템플릿 예시'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TabBarView(
                        children: [
                          Column(
                            children: [
                              Expanded(
                                child: _userTemplateTypes.isEmpty
                                    ? const Center(
                                        child: Text(
                                          '아직 내 템플릿이 없습니다.\n현재 설정으로 템플릿을 추가해 보세요.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: _userTemplateTypes.length,
                                        separatorBuilder: (_, _) =>
                                            const SizedBox(height: 8),
                                        itemBuilder: (_, i) {
                                          final t = _userTemplateTypes[i];
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: AppTheme.border),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        t.name,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '항목 ${t.shiftTimes.length}개',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: AppTheme.textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => _useUserTemplate(t),
                                                  style: ElevatedButton.styleFrom(
                                                    minimumSize: const Size(0, 32),
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                    ),
                                                  ),
                                                  child: const Text('사용하기'),
                                                ),
                                                const SizedBox(width: 6),
                                                IconButton(
                                                  tooltip: '이름 수정',
                                                  onPressed: () async {
                                                    await _renameUserTemplate(t);
                                                    if (!mounted) return;
                                                    sheetSetState(() {});
                                                  },
                                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                                  color: AppTheme.textSecondary,
                                                ),
                                                IconButton(
                                                  tooltip: '삭제',
                                                  onPressed: () async {
                                                    await _deleteUserTemplate(t);
                                                    if (!mounted) return;
                                                    sheetSetState(() {});
                                                  },
                                                  icon: const Icon(Icons.delete_outline, size: 18),
                                                  color: Colors.red,
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    await _createTemplateFromCurrent();
                                    if (!mounted) return;
                                    sheetSetState(() {});
                                  },
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('템플릿 유형 추가'),
                                ),
                              ),
                            ],
                          ),
                          ListView.separated(
                            itemCount: _templateExamples.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final e = _templateExamples[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Row(
                                  children: [
                                    Text(e.emoji, style: const TextStyle(fontSize: 20)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        e.name,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => _useExampleTemplate(e),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(0, 32),
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                      ),
                                      child: const Text('사용하기'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveShiftTimes(List<ShiftTime> times) async {
    if (_profile == null) return;
    final normalized = _normalizeShiftTimes(times);
    final updated = _profile!.copyWith(shiftTimes: normalized);
    _setDraftProfile(updated);
  }


  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }

  String _currentTemplateTypeLabel() {
    if (_userTemplateTypes.isEmpty) {
      return '내 템플릿 없음';
    }

    final currentTimes = _profile?.shiftTimes ?? const <ShiftTime>[];
    for (final template in _userTemplateTypes) {
      if (listEquals(currentTimes, template.shiftTimes)) {
        return template.name;
      }
    }
    return '내 템플릿';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmExitIfNeeded,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          elevation: 0,
          title: const Text(
            '달력 설정',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: AppTheme.textSecondary,
            ),
            onPressed: _onBackPressed,
          ),
          actions: [
            ElevatedButton(
              onPressed: (_hasUnsavedChanges && !_isSaving)
                  ? () => _saveChanges()
                  : null,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                backgroundColor: _hasUnsavedChanges
                    ? AppTheme.primary
                    : AppTheme.textTertiary.withValues(alpha: 0.25),
                foregroundColor:
                    _hasUnsavedChanges ? Colors.white : AppTheme.textSecondary,
                disabledBackgroundColor: AppTheme.textTertiary.withValues(alpha: 0.25),
                disabledForegroundColor: AppTheme.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      '저장',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('템플릿 설정'),
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
                            leading: const Icon(
                              Icons.work_outline,
                              color: AppTheme.textSecondary,
                            ),
                            title: const Text('템플릿 유형'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currentTemplateTypeLabel(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppTheme.textSecondary,
                                ),
                              ],
                            ),
                            onTap: _showWorkPatternPicker,
                          ),
                          if (_userTemplateTypes.isNotEmpty) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '템플릿 항목',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ShiftTimeEditor(
                                    shiftTimes: _profile?.shiftTimes ?? const [],
                                    onChanged: _saveShiftTimes,
                                    enableTypeEdit: true,
                                    enableAddRemove: true,
                                  ),

                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TemplateExample {
  final String pattern;
  final String emoji;
  final String name;

  const _TemplateExample(this.pattern, this.emoji, this.name);
}

class _UserTemplateType {
  final String id;
  final String name;
  final List<ShiftTime> shiftTimes;

  const _UserTemplateType({
    required this.id,
    required this.name,
    required this.shiftTimes,
  });

  _UserTemplateType copyWith({
    String? id,
    String? name,
    List<ShiftTime>? shiftTimes,
  }) {
    return _UserTemplateType(
      id: id ?? this.id,
      name: name ?? this.name,
      shiftTimes: shiftTimes ?? this.shiftTimes,
    );
  }

  factory _UserTemplateType.fromMap(Map<String, dynamic> map) {
    final rawTimes = map['shift_times'];
    final times = rawTimes is List
        ? rawTimes
            .whereType<Map<String, dynamic>>()
            .map(ShiftTime.fromMap)
            .toList()
        : <ShiftTime>[];
    return _UserTemplateType(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '템플릿',
      shiftTimes: times,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'shift_times': shiftTimes.map((e) => e.toMap()).toList(),
  };
}
