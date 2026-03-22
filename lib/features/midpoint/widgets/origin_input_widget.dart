import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart' show supabaseUrl, supabaseAnonKey;
import '../../../core/theme.dart';

class OriginInputWidget extends StatefulWidget {
  final String label;
  final String hint;
  // name: 표시용, latLng: 네이버에서 받은 좌표
  final void Function(String name, LatLng latLng) onSelected;

  const OriginInputWidget({
    super.key,
    required this.label,
    required this.hint,
    required this.onSelected,
  });

  @override
  State<OriginInputWidget> createState() => _OriginInputWidgetState();
}

class _OriginInputWidgetState extends State<OriginInputWidget> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.length < 2) {
      setState(() => _showSuggestions = false);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String query) async {
    try {
      final uri = Uri.parse(
        '$supabaseUrl/functions/v1/naver-place-search?query=${Uri.encodeComponent(query)}',
      );
      final token = Supabase.instance.client.auth.currentSession?.accessToken
          ?? supabaseAnonKey;
      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'apikey': supabaseAnonKey,
      });
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      final places = (data['places'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) {
        setState(() {
          _suggestions = places.take(5).toList();
          _showSuggestions = places.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('[OriginInput] error: $e');
    }
  }

  void _select(Map<String, dynamic> place) {
    final name = place['name'] as String;
    final lat = (place['lat'] as num).toDouble();
    final lng = (place['lng'] as num).toDouble();
    _controller.text = name;
    setState(() => _showSuggestions = false);
    _focus.unfocus();
    widget.onSelected(name, LatLng(lat, lng));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          focusNode: _focus,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            prefixIcon: const Icon(Icons.location_on_outlined,
                color: AppTheme.accent, size: 20),
            filled: true,
            fillColor: AppTheme.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
            ),
          ),
        ),
        if (_showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppTheme.border),
              itemBuilder: (_, i) {
                final p = _suggestions[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined,
                      size: 18, color: AppTheme.textSecondary),
                  title: Text(p['name'] as String,
                      style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                      (p['roadAddress'] as String?)?.isNotEmpty == true
                          ? p['roadAddress'] as String
                          : p['address'] as String? ?? '',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  onTap: () => _select(p),
                );
              },
            ),
          ),
      ],
    );
  }
}
