import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../shared/models/color_mapping.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 기본 매핑 샘플 — 추후 Supabase color_mappings 테이블과 연동
  final List<ColorMapping> _mappings = [
    const ColorMapping(id: '1', colorHex: '#FF5252', workType: '휴무'),
    const ColorMapping(id: '2', colorHex: '#448AFF', workType: '나이트'),
    const ColorMapping(id: '3', colorHex: '#FFCA28', workType: '휴가'),
  ];

  static const List<Color> _presetColors = [
    Color(0xFFFF5252), Color(0xFFFF4081), Color(0xFFFF6D00), Color(0xFFFFCA28),
    Color(0xFF69F0AE), Color(0xFF00BFA5), Color(0xFF448AFF), Color(0xFF3D5AFE),
    Color(0xFFE040FB), Color(0xFF795548), Color(0xFF9E9E9E), Color(0xFF212121),
  ];

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  String _colorToHex(Color color) {
    final r = color.r.round().toRadixString(16).padLeft(2, '0');
    final g = color.g.round().toRadixString(16).padLeft(2, '0');
    final b = color.b.round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  void _showAddDialog() {
    String workType = '';
    Color selectedColor = _presetColors.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            '색상 매핑 추가',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '색상 선택',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetColors.map((color) {
                  final isSelected = selectedColor.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: AppTheme.primary, width: 3)
                            : Border.all(color: Colors.transparent, width: 3),
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withAlpha(120), blurRadius: 8)]
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
              const Text(
                '근무 형태',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                autofocus: true,
                onChanged: (v) => workType = v,
                decoration: InputDecoration(
                  hintText: '예) 휴무, 나이트, 데이...',
                  hintStyle: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
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
              onPressed: () {
                if (workType.trim().isEmpty) return;
                setState(() {
                  _mappings.add(ColorMapping(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    colorHex: _colorToHex(selectedColor),
                    workType: workType.trim(),
                  ));
                });
                Navigator.pop(ctx);
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          // 색상 매핑 섹션
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '색상 - 근무 형태 매핑',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '스케줄 이미지의 색상과 근무 형태를 연결하세요',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                        '매핑이 없어요. 아래 버튼으로 추가하세요.',
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
                            title: Text(
                              m.workType,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 15),
                            ),
                            subtitle: Text(
                              m.colorHex,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppTheme.textSecondary, size: 20),
                              onPressed: () =>
                                  setState(() => _mappings.removeAt(i)),
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

          // 커플 정보 섹션 (추후 구현)
          const Text(
            '커플 정보',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Text(
              '로그인 후 커플 연결 코드를 공유하세요\n(다음 단계에서 구현 예정)',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
