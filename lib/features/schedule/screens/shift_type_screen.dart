import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../core/models/shift_type.dart';
import '../../../core/models/shift_type.dart';
import '../../services/user_settings_service.dart';

class ShiftTypeScreen extends StatefulWidget {
  const ShiftTypeScreen({super.key});

  @override
  State<ShiftTypeScreen> createState() => _ShiftTypeScreenState();
}

class _ShiftTypeScreenState extends State<ShiftTypeScreen> {
  ShiftType _selectedType = ShiftType.regularOffice;
  String _selectedDefaultShift = '주간근무';
  bool _isLoading = false;

  final List<Map<String, String>> _defaultShiftOptions = [
    {'value': '주간근무', 'label': '주간 근무'},
    {'value': '휴무', 'label': '휴무'},
    {'value': '당직', 'label': '당직'},
    {'value': '휴가', 'label': '휴가'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final service = UserSettingsService();
    final settings = await service.getUserSettings(userId);
    if (settings != null && mounted) {
      setState(() {
        _selectedType = settings!.shiftType;
        _selectedDefaultShift = settings!.defaultShift;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final service = UserSettingsService();
      await service.upsertUserSettings(
        userId: userId,
        shiftType: _selectedType,
        defaultShift: _selectedDefaultShift,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('근무형태가 저장되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('근무형태 설정'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('근무형태 선택'),
                ...ShiftType.values.map((type) {
                  return _buildTypeTile(type);
                }),
                const SizedBox(height: 32),
                _buildSectionHeader('디폴트 근무형태'),
                _buildDefaultShiftSelector(),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('저장', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTypeTile(ShiftType type) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.primary : AppTheme.border,
              ),
              child: Icon(
                isSelected ? Icons.check : null,
                color: isSelected ? Colors.white : AppTheme.border,
                size: 16,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                type.displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultShiftSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline<String>(
        value: _selectedDefaultShift,
        items: _defaultShiftOptions.map((option) {
          return DropdownMenuItem(
            value: option['value'] as String,
            child: Text(option['label'] as String),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedDefaultShift = value!);
          }
        },
        style: TextStyle(
          fontSize: 16,
          color: AppTheme.textPrimary,
        ),
        dropdownColor: Colors.transparent,
        icon: Icon(
          Icons.arrow_drop_down,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
