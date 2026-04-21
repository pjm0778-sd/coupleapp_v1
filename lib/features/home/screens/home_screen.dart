import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme.dart';
import '../../../core/notification_manager.dart';
import '../../../core/holiday_service.dart';
import '../../../core/profile_change_notifier.dart';
import '../../../shared/models/schedule.dart';
import '../../profile/models/couple_profile.dart';
import '../../profile/services/profile_service.dart';
import '../models/weather_data.dart';
import '../data/city_coordinates.dart';
import '../services/home_service.dart';
import '../services/weather_service.dart';
import '../../../core/home_widget_service.dart';
import '../../calendar/screens/calendar_screen.dart';
import '../../couple/screens/couple_connect_screen.dart';
import '../../notifications/screens/notification_history_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../transport/screens/transport_search_screen.dart';
import '../../midpoint/screens/midpoint_search_screen.dart';
import 'date_recommendation_screen.dart';
import 'relationship_timeline_screen.dart';
import 'weather_detail_screen.dart';

// ─── Home Feature Card Model ─────────────────────────────────────────────────

class _HomeFeatureCardData {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _HomeFeatureCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });
}

class _DateInsightCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback? onTap;

  const _DateInsightCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    this.onTap,
  });
}

// ─── HomeScreen ────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _homeService = HomeService();
  final _profileService = ProfileService();
  final _imagePicker = ImagePicker();

  Map<String, dynamic> _data = {};
  CoupleProfile? _profile;
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  RealtimeChannel? _schedulesChannel;
  RealtimeChannel? _couplesChannel;
  StreamSubscription<void>? _profileChangeSub;
  String? _coupleId;

  // 커플 배경 사진 (로컬 저장)
  String? _couplePhotoPath;      // 최종 크롭 이미지
  String? _couplePhotoSourcePath; // 원본 이미지
  double _heroPhotoScale = 1.0;
  Offset _heroPhotoOffset = Offset.zero;
  bool _useHeroPhotoAsMainBackground = false;
  int? _defaultHeroPreset;
  bool _hasDefaultHeroPreset = false;

  static const _kPhotoKey = 'couple_bg_photo_path';
  static const _kPhotoSourceKey = 'couple_bg_photo_source_path';
  static const _kPhotoScaleKey = 'couple_bg_photo_scale';
  static const _kPhotoOffsetXKey = 'couple_bg_photo_offset_x';
  static const _kPhotoOffsetYKey = 'couple_bg_photo_offset_y';
  static const _kPhotoUseAsMainBgKey = 'couple_bg_use_main_glass';
  static const _kDefaultHeroPresetKey = 'couple_default_hero_preset';
  static const _kDefaultHeroPresetAssets = <String>[
    'assets/images/main background.png',
    'assets/images/main background2.png',
  ];
  static const double _kHeroAspectRatio = 1.52;
  static const int _kHeroExportWidth = 1520;
  static const int _kHeroExportHeight = 1000;

  static const int _kScheduleBasePage = 1000;
  final PageController _schedulePageController = PageController(
    initialPage: _kScheduleBasePage,
    viewportFraction: 0.9,
  );
  static const double _kDateInsightCardWidth = 156;

  final Map<String, Map<String, List<Schedule>>> _scheduleByDate = {};
  final Set<String> _scheduleLoadingDates = <String>{};
  int _schedulePage = _kScheduleBasePage;
  final WeatherService _weatherService = WeatherService();
  WeatherData? _myWeatherData;
  WeatherData? _partnerWeatherData;
  WeatherData? _schedulePlaceWeatherData;
  String? _myWeatherStatusText;
  String? _partnerWeatherStatusText;
  String? _schedulePlaceStatusText;
  String? _schedulePlaceLabel;
  String? _schedulePlaceCityForDetail;
  bool _isScheduleWeatherLoading = false;
  int _weatherRequestSeq = 0;
  final Set<String> _weatherRequestedDateKeys = <String>{};
  final List<String> _cityKeysByLength =
      (cityCoordinates.keys.toList()..sort((a, b) => b.length.compareTo(a.length)));
  String? _activeWeatherDateKey;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCouplePhoto();
    _profileChangeSub = ProfileChangeNotifier().onChange.listen((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoadedOnce) _loadData();
    _hasLoadedOnce = true;
  }

  // ─── Photo ──────────────────────────────────────────────────────────────────

  Future<void> _loadCouplePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_kPhotoKey);
    final sourcePath = prefs.getString(_kPhotoSourceKey);
    final scale = prefs.getDouble(_kPhotoScaleKey) ?? 1.0;
    final offsetX = prefs.getDouble(_kPhotoOffsetXKey) ?? 0.0;
    final offsetY = prefs.getDouble(_kPhotoOffsetYKey) ?? 0.0;
    final useAsMainBg = prefs.getBool(_kPhotoUseAsMainBgKey) ?? false;
    final hasDefaultHeroPreset = prefs.containsKey(_kDefaultHeroPresetKey);
    final defaultHeroPreset = prefs.getInt(_kDefaultHeroPresetKey);

    if (!mounted) return;
    setState(() {
      _heroPhotoScale = scale.clamp(0.5, 4.0);
      _heroPhotoOffset = Offset(offsetX, offsetY);
      _useHeroPhotoAsMainBackground = useAsMainBg;
      _hasDefaultHeroPreset = hasDefaultHeroPreset && defaultHeroPreset != null;
      _defaultHeroPreset = _hasDefaultHeroPreset
          ? defaultHeroPreset!.clamp(0, _kDefaultHeroPresetAssets.length - 1)
          : null;
      if (sourcePath != null && File(sourcePath).existsSync()) {
        _couplePhotoSourcePath = sourcePath;
      }
      if (path != null && File(path).existsSync()) {
        _couplePhotoPath = path;
      }
    });
  }

  Future<void> _pickCouplePhoto() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;

      // Copy through XFile API to avoid loading full image bytes into memory.
      final docsDir = await getApplicationDocumentsDirectory();
      final destPath =
          '${docsDir.path}/couple_hero_bg_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await picked.saveTo(destPath);
      if (!mounted) return;

      await _openHeroPhotoEditor(sourcePath: destPath, sourceIsTemp: true);
    } catch (e, st) {
      debugPrint('pick photo failed: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 불러오지 못했어요. 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _editCurrentCouplePhoto() async {
    final sourcePath = _couplePhotoSourcePath;
    final fallbackPath = _couplePhotoPath;

    final pathToEdit =
        sourcePath != null && File(sourcePath).existsSync()
            ? sourcePath
            : fallbackPath;

    if (pathToEdit == null || !File(pathToEdit).existsSync()) {
      await _pickCouplePhoto();
      return;
    }
    await _openHeroPhotoEditor(sourcePath: pathToEdit, sourceIsTemp: false);
  }

  Future<void> _saveDefaultHeroPreset(int preset, bool useAsMainBg) async {
    final normalized = preset.clamp(0, _kDefaultHeroPresetAssets.length - 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDefaultHeroPresetKey, normalized);
    await prefs.setBool(_kPhotoUseAsMainBgKey, useAsMainBg);
    if (!mounted) return;
    setState(() {
      _defaultHeroPreset = normalized;
      _hasDefaultHeroPreset = true;
      _useHeroPhotoAsMainBackground = useAsMainBg;
    });
  }

  Future<void> _clearDefaultHeroPreset(bool useAsMainBg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDefaultHeroPresetKey);
    await prefs.setBool(_kPhotoUseAsMainBgKey, useAsMainBg);
    if (!mounted) return;
    setState(() {
      _defaultHeroPreset = null;
      _hasDefaultHeroPreset = false;
      _useHeroPhotoAsMainBackground = useAsMainBg;
    });
  }

  Future<void> _showHeroBackgroundOptionsSheet() async {
    bool useAsMainBg = _useHeroPhotoAsMainBackground;
    int? selectedPreset = _hasDefaultHeroPreset ? _defaultHeroPreset : null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxSheetHeight = constraints.maxHeight * 0.86;
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxSheetHeight),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                Row(
                  children: [
                    const Text(
                      '기본 배경 선택',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '원하는 기본 배경을 고른 뒤 하단 적용 버튼으로 반영해요.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '메인 배경에 글래스모피즘 적용',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '기본 배경 선택 시 홈 전체 배경에도 반영',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: useAsMainBg,
                        activeColor: AppTheme.primary,
                        onChanged: (value) {
                          setStateSheet(() {
                            useAsMainBg = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DefaultBgOptionTile(
                  title: '배경 없음',
                  subtitle: '기본 배경 이미지를 사용하지 않음',
                  selected: selectedPreset == null,
                  onTap: () {
                    setStateSheet(() {
                      selectedPreset = null;
                    });
                  },
                ),
                const SizedBox(height: 8),
                _DefaultBgOptionTile(
                  title: '초원 피크닉',
                  subtitle: '따뜻한 들판과 강, 마을 풍경',
                  selected: selectedPreset == 0,
                  onTap: () {
                    setStateSheet(() {
                      selectedPreset = 0;
                    });
                  },
                ),
                const SizedBox(height: 8),
                _DefaultBgOptionTile(
                  title: '산길 들판',
                  subtitle: '푸른 능선과 꽃길 산책 분위기',
                  selected: selectedPreset == 1,
                  onTap: () {
                    setStateSheet(() {
                      selectedPreset = 1;
                    });
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _pickCouplePhoto();
                    },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('내 사진으로 설정'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedPreset == null) {
                        await _clearDefaultHeroPreset(useAsMainBg);
                      } else {
                        await _saveDefaultHeroPreset(
                          selectedPreset!,
                          useAsMainBg,
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('적용'),
                  ),
                ),
                        ],
                      ),
                    ),
                  );
                },
                ),
              );
          },
        );
      },
    );
  }

  Future<void> _openHeroPhotoEditor({
    required String sourcePath,
    required bool sourceIsTemp,
    bool resetTransform = false,
  }) async {
    try {
      double scale = _heroPhotoScale;
      Offset offset = _heroPhotoOffset;

      if (resetTransform) {
        scale = 1.0;
        offset = Offset.zero;
      }

      // Let gallery transition finish before opening dialog.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;

      final preview = await _showHeroPhotoPreview(
        sourcePath,
        initialScale: scale,
        initialOffset: offset,
        initialUseAsMainBackground: _useHeroPhotoAsMainBackground,
      );
      if (preview == null) {
        if (sourceIsTemp) {
          final tempFile = File(sourcePath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
        return;
      }

      if (preview.reselect) {
        if (sourceIsTemp) {
          final tempFile = File(sourcePath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
        if (!mounted) return;
        await Future<void>.delayed(const Duration(milliseconds: 80));
        if (!mounted) return;
        await _pickCouplePhoto();
        return;
      }

      if (!preview.confirmed) {
        if (sourceIsTemp) {
          final tempFile = File(sourcePath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
        return;
      }

      String finalPath = sourcePath;
      double finalScale = preview.scale;
      Offset finalOffset = preview.offset;
      try {
        final oldCroppedPath = _couplePhotoPath;
        final croppedPath = await _exportHeroCroppedImage(
          sourcePath: sourcePath,
          preview: preview,
        );
        finalPath = croppedPath;
        finalScale = 1.0;
        finalOffset = Offset.zero;
        // Keep the original file so re-editing can always start from source.
        if (oldCroppedPath != null && oldCroppedPath != croppedPath) {
          final oldFile = File(oldCroppedPath);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        }
      } catch (e, st) {
        debugPrint('hero crop export failed: $e');
        debugPrintStack(stackTrace: st);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPhotoSourceKey, sourcePath);
      await prefs.setString(_kPhotoKey, finalPath);
      await prefs.setDouble(_kPhotoScaleKey, finalScale);
      await prefs.setDouble(_kPhotoOffsetXKey, finalOffset.dx);
      await prefs.setDouble(_kPhotoOffsetYKey, finalOffset.dy);
      await prefs.setBool(
        _kPhotoUseAsMainBgKey,
        preview.useAsMainBackground,
      );

      if (!mounted) return;
      setState(() {
        _couplePhotoSourcePath = sourcePath;
        _couplePhotoPath = finalPath;
        _heroPhotoScale = finalScale;
        _heroPhotoOffset = finalOffset;
        _useHeroPhotoAsMainBackground = preview.useAsMainBackground;
      });
    } catch (e, st) {
      debugPrint('open photo editor failed: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진 편집 화면을 열지 못했어요. 다시 시도해 주세요.')),
      );
    }
  }

  Future<_PhotoPreviewResult?> _showHeroPhotoPreview(
    String imagePath, {
    double initialScale = 1.0,
    Offset initialOffset = const Offset(0, 0),
    bool initialUseAsMainBackground = false,
  }) async {
    double scale = initialScale;
    Offset offset = initialOffset;
    bool cropToCard = false;
    bool fillToCard = false;
    double? scaleBeforeFill;
    Offset? offsetBeforeFill;
    Offset focalStart = Offset.zero;
    Offset offsetStart = Offset.zero;
    double scaleStart = scale;
    double viewportWidth = 1;
    double viewportHeight = 1;
    double sourceImageWidth = 1;
    double sourceImageHeight = 1;
    bool useAsMainBackground = initialUseAsMainBackground;

    try {
      final bytes = await File(imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      sourceImageWidth = image.width.toDouble();
      sourceImageHeight = image.height.toDouble();
      image.dispose();
    } catch (_) {}

    double cropMinScale(
      double viewportW,
      double viewportH,
      double srcW,
      double srcH,
    ) {
      final containScale = math.min(viewportW / srcW, viewportH / srcH);
      final baseDrawW = srcW * containScale;
      final baseDrawH = srcH * containScale;

      late final double cropW;
      late final double cropH;
      if (viewportW / viewportH > _kHeroAspectRatio) {
        cropH = viewportH;
        cropW = viewportH * _kHeroAspectRatio;
      } else {
        cropW = viewportW;
        cropH = viewportW / _kHeroAspectRatio;
      }

      final minScaleByWidth = cropW / baseDrawW;
      final minScaleByHeight = cropH / baseDrawH;
      return math.max(1.0, math.max(minScaleByWidth, minScaleByHeight));
    }

    Rect cropRectForViewport(double viewportW, double viewportH) {
      late final double cropW;
      late final double cropH;
      if (viewportW / viewportH > _kHeroAspectRatio) {
        cropH = viewportH;
        cropW = viewportH * _kHeroAspectRatio;
      } else {
        cropW = viewportW;
        cropH = viewportW / _kHeroAspectRatio;
      }
      return Rect.fromCenter(
        center: Offset(viewportW / 2, viewportH / 2),
        width: cropW,
        height: cropH,
      );
    }

    Offset clampCropOffset(
      Offset targetOffset,
      double targetScale,
      double viewportW,
      double viewportH,
      double srcW,
      double srcH,
    ) {
      final containScale = math.min(viewportW / srcW, viewportH / srcH);
      final drawW = srcW * containScale * targetScale;
      final drawH = srcH * containScale * targetScale;

      late final double cropW;
      late final double cropH;
      if (viewportW / viewportH > _kHeroAspectRatio) {
        cropH = viewportH;
        cropW = viewportH * _kHeroAspectRatio;
      } else {
        cropW = viewportW;
        cropH = viewportW / _kHeroAspectRatio;
      }

      final cropLeft = (viewportW - cropW) / 2;
      final cropRight = cropLeft + cropW;
      final cropTop = (viewportH - cropH) / 2;
      final cropBottom = cropTop + cropH;

      final minOffsetX = cropRight - viewportW / 2 - drawW / 2;
      final maxOffsetX = cropLeft - viewportW / 2 + drawW / 2;
      final minOffsetY = cropBottom - viewportH / 2 - drawH / 2;
      final maxOffsetY = cropTop - viewportH / 2 + drawH / 2;

      // Floating-point rounding can invert min/max by a tiny epsilon.
      // Normalize bounds to avoid clamp() ArgumentError.
      final lowerX = math.min(minOffsetX, maxOffsetX);
      final upperX = math.max(minOffsetX, maxOffsetX);
      final lowerY = math.min(minOffsetY, maxOffsetY);
      final upperY = math.max(minOffsetY, maxOffsetY);

      return Offset(
        targetOffset.dx.clamp(lowerX, upperX),
        targetOffset.dy.clamp(lowerY, upperY),
      );
    }

    Offset clampFreeOffset(
      Offset targetOffset,
      double targetScale,
      double viewportW,
      double viewportH,
      double srcW,
      double srcH,
    ) {
      final containScale = math.min(viewportW / srcW, viewportH / srcH);
      final drawW = srcW * containScale * targetScale;
      final drawH = srcH * containScale * targetScale;

      final halfX = math.max(0.0, (drawW - viewportW) / 2);
      final halfY = math.max(0.0, (drawH - viewportH) / 2);

      return Offset(
        targetOffset.dx.clamp(-halfX, halfX),
        targetOffset.dy.clamp(-halfY, halfY),
      );
    }

    return Navigator.push<_PhotoPreviewResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.black87,
                  title: const Text(
                    '배경 미리보기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  actions: [
                    TextButton.icon(
                      onPressed: () {
                        setStateDialog(() {
                          scale = 1.0;
                          offset = Offset.zero;
                        });
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text(
                        '초기화',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                body: Column(
                  children: [
                    // 모드 선택 바
                    Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('원본 사이즈'),
                                selected: !cropToCard,
                                onSelected: (_) => setStateDialog(() {
                                  cropToCard = false;
                                  fillToCard = false;
                                  scaleBeforeFill = null;
                                  offsetBeforeFill = null;
                                  offset = clampFreeOffset(
                                    offset,
                                    scale,
                                    viewportWidth,
                                    viewportHeight,
                                    sourceImageWidth,
                                    sourceImageHeight,
                                  );
                                }),
                              ),
                              ChoiceChip(
                                label: const Text('카드 크기로 자르기'),
                                selected: cropToCard,
                                selectedColor: AppTheme.primaryLight,
                                onSelected: (_) => setStateDialog(() {
                                  cropToCard = true;
                                  final minScale = cropMinScale(
                                    viewportWidth,
                                    viewportHeight,
                                    sourceImageWidth,
                                    sourceImageHeight,
                                  );
                                  scale = scale.clamp(minScale, 4.0);
                                  offset = clampCropOffset(
                                    offset,
                                    scale,
                                    viewportWidth,
                                    viewportHeight,
                                    sourceImageWidth,
                                    sourceImageHeight,
                                  );
                                }),
                              ),
                              if (cropToCard)
                                OutlinedButton(
                                  onPressed: () {
                                    setStateDialog(() {
                                      if (!fillToCard) {
                                        scaleBeforeFill = scale;
                                        offsetBeforeFill = offset;
                                        fillToCard = true;
                                        scale = 1.0;
                                        offset = Offset.zero;
                                      } else {
                                        fillToCard = false;
                                        final minScale = cropMinScale(
                                          viewportWidth,
                                          viewportHeight,
                                          sourceImageWidth,
                                          sourceImageHeight,
                                        );
                                        final restoredScale =
                                            (scaleBeforeFill ?? 1.0).clamp(minScale, 4.0);
                                        final restoredOffset =
                                            offsetBeforeFill ?? Offset.zero;
                                        scale = restoredScale;
                                        offset = clampCropOffset(
                                          restoredOffset,
                                          restoredScale,
                                          viewportWidth,
                                          viewportHeight,
                                          sourceImageWidth,
                                          sourceImageHeight,
                                        );
                                      }
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: fillToCard
                                          ? AppTheme.primary
                                          : Colors.white54,
                                    ),
                                  ),
                                  child: Text(
                                    '채우기',
                                    style: TextStyle(
                                      color: fillToCard
                                          ? AppTheme.primary
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cropToCard
                                ? fillToCard
                                    ? '채우기 적용: 원본 전체를 카드 비율로 꽉 채웁니다.'
                                    : '점선 영역만 카드에 표시됩니다. (축소 최소 1.0x)'
                                : '두 손가락으로 확대/이동해 위치를 조정하세요.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        '메인 배경에 적용',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'D+DAY 사진을 홈 전체 배경으로 글래스모피즘 처리',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: useAsMainBackground,
                                  activeColor: AppTheme.primary,
                                  onChanged: (value) {
                                    setStateDialog(() {
                                      useAsMainBackground = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 이미지 미리보기 (확장)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final height = constraints.maxHeight;
                          viewportWidth = width;
                          viewportHeight = height;

                          return GestureDetector(
                            onScaleStart: (details) {
                              focalStart = details.focalPoint;
                              offsetStart = offset;
                              scaleStart = scale;
                            },
                            onScaleUpdate: (details) {
                              setStateDialog(() {
                                fillToCard = false;
                                final minScale = cropToCard
                                    ? cropMinScale(
                                        viewportWidth,
                                        viewportHeight,
                                        sourceImageWidth,
                                        sourceImageHeight,
                                      )
                                    : 0.5;
                                scale =
                                    (scaleStart * details.scale).clamp(minScale, 4.0);
                                final delta = details.focalPoint - focalStart;
                                final targetOffset = offsetStart + delta;
                                offset = cropToCard
                                    ? clampCropOffset(
                                        targetOffset,
                                        scale,
                                        viewportWidth,
                                        viewportHeight,
                                        sourceImageWidth,
                                        sourceImageHeight,
                                      )
                                    : clampFreeOffset(
                                        targetOffset,
                                        scale,
                                        viewportWidth,
                                        viewportHeight,
                                        sourceImageWidth,
                                        sourceImageHeight,
                                      );
                              });
                            },
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Transform(
                                    transform: Matrix4.identity()
                                      ..translate(offset.dx, offset.dy)
                                      ..translate(width / 2, height / 2)
                                      ..scale(scale)
                                      ..translate(-width / 2, -height / 2),
                                    child: ImageFiltered(
                                      imageFilter: ui.ImageFilter.blur(
                                        sigmaX: 28,
                                        sigmaY: 28,
                                      ),
                                      child: Image.file(
                                        File(imagePath),
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.low,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppTheme.primary
                                              .withValues(alpha: 0.38),
                                          const Color(0xFFF2A88D)
                                              .withValues(alpha: 0.28),
                                          AppTheme.accent
                                              .withValues(alpha: 0.22),
                                        ],
                                        stops: const [0.0, 0.55, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                                if (cropToCard && fillToCard)
                                  Positioned.fromRect(
                                    rect: cropRectForViewport(width, height),
                                    child: Image.file(
                                      File(imagePath),
                                      fit: BoxFit.fill,
                                      filterQuality: FilterQuality.medium,
                                    ),
                                  )
                                else
                                  Positioned.fill(
                                    child: Transform(
                                      transform: Matrix4.identity()
                                        ..translate(offset.dx, offset.dy)
                                        ..translate(width / 2, height / 2)
                                        ..scale(scale)
                                        ..translate(-width / 2, -height / 2),
                                      child: Image.file(
                                        File(imagePath),
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.medium,
                                      ),
                                    ),
                                  ),
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.10),
                                          Colors.black.withValues(alpha: 0.28),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _DashedRRectPainter(
                                        color: cropToCard
                                            ? const Color(0xFFFFFFFF)
                                            : Colors.white
                                                .withValues(alpha: 0.9),
                                        strokeWidth: 2,
                                        dashLength: 9,
                                        gapLength: 6,
                                        radius: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                if (cropToCard)
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _CropFramePainter(
                                        cardAspectRatio: _kHeroAspectRatio,
                                        outerColor: Colors.black
                                            .withValues(alpha: 0.60),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // 하단 버튼
                    Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(
                                ctx,
                                const _PhotoPreviewResult(
                                  confirmed: false,
                                  reselect: true,
                                  scale: 1,
                                  offset: Offset.zero,
                                ),
                              );
                            },
                            child: const Text(
                              '사진 다시 선택',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.pop(
                                ctx,
                                _PhotoPreviewResult(
                                  confirmed: true,
                                  scale: scale,
                                  offset: offset,
                                  viewportWidth: viewportWidth,
                                  viewportHeight: viewportHeight,
                                  cropToCard: cropToCard,
                                  fillToCard: fillToCard,
                                  useAsMainBackground: useAsMainBackground,
                                ),
                              );
                            },
                            child: const Text('이 사진 사용'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<String> _exportHeroCroppedImage({
    required String sourcePath,
    required _PhotoPreviewResult preview,
  }) async {
    final sourceBytes = await File(sourcePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(sourceBytes);
    final frame = await codec.getNextFrame();
    final srcImage = frame.image;

    if (preview.cropToCard) {
      return _exportCroppedToCard(
        srcImage: srcImage,
        preview: preview,
      );
    } else {
      return _exportWithSourceAspectRatio(
        srcImage: srcImage,
        preview: preview,
      );
    }
  }

  Future<String> _exportCroppedToCard({
    required ui.Image srcImage,
    required _PhotoPreviewResult preview,
  }) async {
    final outW = _kHeroExportWidth.toDouble();
    final outH = _kHeroExportHeight.toDouble();
    final srcW = srcImage.width.toDouble();
    final srcH = srcImage.height.toDouble();

    final viewportW = preview.viewportWidth <= 0 ? outW : preview.viewportWidth;
    final viewportH = preview.viewportHeight <= 0 ? outH : preview.viewportHeight;
    final userScale = preview.scale.clamp(1.0, 4.0);

    // Match preview: image is shown with BoxFit.contain, then transformed by scale/offset.
    final containScale = math.min(viewportW / srcW, viewportH / srcH);
    final drawW = srcW * containScale * userScale;
    final drawH = srcH * containScale * userScale;
    final previewDstRect = Rect.fromCenter(
      center: Offset(
        viewportW / 2 + preview.offset.dx,
        viewportH / 2 + preview.offset.dy,
      ),
      width: drawW,
      height: drawH,
    );

    // Match crop frame painter geometry from preview screen.
    late final double cropW;
    late final double cropH;
    if (viewportW / viewportH > _kHeroAspectRatio) {
      cropH = viewportH;
      cropW = viewportH * _kHeroAspectRatio;
    } else {
      cropW = viewportW;
      cropH = viewportW / _kHeroAspectRatio;
    }
    final cropRect = Rect.fromCenter(
      center: Offset(viewportW / 2, viewportH / 2),
      width: cropW,
      height: cropH,
    );

    final scaleX = outW / cropRect.width;
    final scaleY = outH / cropRect.height;
    final mappedDstRect = Rect.fromLTWH(
      (previewDstRect.left - cropRect.left) * scaleX,
      (previewDstRect.top - cropRect.top) * scaleY,
      previewDstRect.width * scaleX,
      previewDstRect.height * scaleY,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final blurRect = Rect.fromCenter(
      center: mappedDstRect.center,
      width: math.max(mappedDstRect.width, outW),
      height: math.max(mappedDstRect.height, outH),
    );

    canvas.clipRect(Rect.fromLTWH(0, 0, outW, outH));
    canvas.drawImageRect(
      srcImage,
      Rect.fromLTWH(0, 0, srcW, srcH),
      blurRect,
      Paint()
        ..filterQuality = FilterQuality.low
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
    );

    final glowPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(outW, outH),
        [
          const Color(0x61E07A84),
          const Color(0x47F2A88D),
          const Color(0x387A98BD),
        ],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, outW, outH), glowPaint);
    if (preview.fillToCard) {
      // Stretch full source into card output so the whole image is included.
      canvas.drawImageRect(
        srcImage,
        Rect.fromLTWH(0, 0, srcW, srcH),
        Rect.fromLTWH(0, 0, outW, outH),
        Paint()..filterQuality = FilterQuality.high,
      );
    } else {
      canvas.drawImageRect(
        srcImage,
        Rect.fromLTWH(0, 0, srcW, srcH),
        mappedDstRect,
        Paint()..filterQuality = FilterQuality.high,
      );
    }

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(_kHeroExportWidth, _kHeroExportHeight);
    final pngBytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    if (pngBytes == null) {
      throw StateError('failed to encode cropped hero image');
    }

    srcImage.dispose();
    rendered.dispose();

    final docsDir = await getApplicationDocumentsDirectory();
    final path =
        '${docsDir.path}/couple_hero_cropped_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(path).writeAsBytes(pngBytes.buffer.asUint8List(), flush: true);
    return path;
  }

  Future<String> _exportWithSourceAspectRatio({
    required ui.Image srcImage,
    required _PhotoPreviewResult preview,
  }) async {
    final outW = _kHeroExportWidth.toDouble();
    final outH = _kHeroExportHeight.toDouble();
    final srcW = srcImage.width.toDouble();
    final srcH = srcImage.height.toDouble();

    final baseScale = math.min(outW / srcW, outH / srcH);
    final coverScale = math.max(outW / srcW, outH / srcH);
    final scale = preview.scale.clamp(0.5, 4.0);
    final drawW = srcW * baseScale * scale;
    final drawH = srcH * baseScale * scale;
    final coverW = srcW * coverScale * scale;
    final coverH = srcH * coverScale * scale;

    final viewportW =
        preview.viewportWidth <= 0 ? outW : preview.viewportWidth;
    final viewportH =
        preview.viewportHeight <= 0 ? outH : preview.viewportHeight;
    final mappedOffset = Offset(
      preview.offset.dx * (outW / viewportW),
      preview.offset.dy * (outH / viewportH),
    );

    final dstRect = Rect.fromCenter(
      center: Offset(
        outW / 2 + mappedOffset.dx,
        outH / 2 + mappedOffset.dy,
      ),
      width: drawW,
      height: drawH,
    );
    final blurRect = Rect.fromCenter(
      center: Offset(
        outW / 2 + mappedOffset.dx,
        outH / 2 + mappedOffset.dy,
      ),
      width: coverW,
      height: coverH,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.clipRect(Rect.fromLTWH(0, 0, outW, outH));
    canvas.drawImageRect(
      srcImage,
      Rect.fromLTWH(0, 0, srcW, srcH),
      blurRect,
      Paint()
        ..filterQuality = FilterQuality.low
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
    );

    final glowPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(outW, outH),
        [
          const Color(0x61E07A84),
          const Color(0x47F2A88D),
          const Color(0x387A98BD),
        ],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, outW, outH), glowPaint);

    canvas.drawImageRect(
      srcImage,
      Rect.fromLTWH(0, 0, srcW, srcH),
      dstRect,
      Paint()..filterQuality = FilterQuality.high,
    );

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(_kHeroExportWidth, _kHeroExportHeight);
    final pngBytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    if (pngBytes == null) {
      throw StateError('failed to encode cropped hero image');
    }

    srcImage.dispose();
    rendered.dispose();

    final docsDir = await getApplicationDocumentsDirectory();
    final path =
        '${docsDir.path}/couple_hero_cropped_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(path).writeAsBytes(pngBytes.buffer.asUint8List(), flush: true);
    return path;
  }

  // ─── Realtime ───────────────────────────────────────────────────────────────

  void _setupRealtime() {
    if (_coupleId == null || _schedulesChannel != null) return;

    _schedulesChannel =
        Supabase.instance.client
            .channel('public:schedules_home')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'schedules',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'couple_id',
                value: _coupleId!,
              ),
              callback: (payload) {
                debugPrint('Realtime change detected: ${payload.eventType}');
                if (mounted) _loadData();
              },
            )
          ..subscribe();

    _couplesChannel ??=
        Supabase.instance.client
            .channel('public:couples_home')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'couples',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: _coupleId!,
              ),
              callback: (_) {
                if (mounted) _loadData();
              },
            )
          ..subscribe();
  }

  @override
  void dispose() {
    _schedulesChannel?.unsubscribe();
    _couplesChannel?.unsubscribe();
    _profileChangeSub?.cancel();
    _schedulePageController.dispose();
    super.dispose();
  }

  // ─── Data Loading ────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    _coupleId = await _homeService.getCoupleId();
    if (_coupleId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _homeService.getHomeSummary(_coupleId!),
        _profileService.loadMyProfile(),
      ]);
      if (mounted) {
        final homeData = results[0] as Map<String, dynamic>;
        final loadedProfile = results[1] as CoupleProfile?;
        setState(() {
          _data = homeData;
          _profile = loadedProfile;
          _scheduleByDate.clear();
          final todayKey = _dateKey(DateTime.now());
          final tomorrowKey = _dateKey(
            DateTime.now().add(const Duration(days: 1)),
          );
          final todaySchedules =
              homeData['today_schedules'] as Map<String, List<Schedule>>?;
          final tomorrowSchedules =
              homeData['tomorrow_schedules'] as Map<String, List<Schedule>>?;
          if (todaySchedules != null) {
            _scheduleByDate[todayKey] = todaySchedules;
          }
          if (tomorrowSchedules != null) {
            _scheduleByDate[tomorrowKey] = tomorrowSchedules;
          }
          _isLoading = false;
        });
        _ensureSchedulesLoadedFor(_dateForPage(_schedulePage + 1));
        _setupRealtime();
        _checkNotifications(_data);
        await _syncScheduleWeatherForDate(_dateForPage(_schedulePage));
        _updateHomeWidget();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncScheduleWeatherForDate(DateTime date) async {
    final dateKey = _dateKey(date);
    final todayKey = _dateKey(DateTime.now());
    final isToday = dateKey == todayKey;

    if (isToday || _weatherRequestedDateKeys.contains(dateKey)) {
      if (isToday) {
        _weatherRequestedDateKeys.add(dateKey);
      }
      await _loadScheduleWeatherForDate(_profile, date);
      return;
    }

    if (!mounted) return;
    setState(() {
      _myWeatherData = null;
      _partnerWeatherData = null;
      _schedulePlaceWeatherData = null;
      _myWeatherStatusText = null;
      _partnerWeatherStatusText = null;
      _schedulePlaceStatusText = null;
      _schedulePlaceLabel = null;
      _schedulePlaceCityForDetail = null;
      _isScheduleWeatherLoading = false;
      _activeWeatherDateKey = null;
    });
  }

  Future<void> _onTapScheduleWeatherFetch(DateTime date) async {
    final key = _dateKey(date);
    _weatherRequestedDateKeys.add(key);
    await _loadScheduleWeatherForDate(_profile, date);
  }

  String? _extractCityFromLocation(String? location) {
    if (location == null) return null;
    final text = location.trim();
    if (text.isEmpty) return null;
    for (final city in _cityKeysByLength) {
      if (text.contains(city)) return city;
    }
    return null;
  }

  ({String label, String? city, double? lat, double? lng})? _pickScheduleWeatherSource(
    DateTime date,
  ) {
    final daySchedules = _scheduleByDate[_dateKey(date)];
    if (daySchedules == null) return null;

    final all = <Schedule>[
      ...(daySchedules['mine'] ?? const []),
      ...(daySchedules['partner'] ?? const []),
    ];

    int score(Schedule s) {
      final category = (s.category ?? '').trim();
      var value = 0;
      if (category == '데이트' || category == '약속' || category == '여행') {
        value += 100;
      }
      if (s.ownerType == 'couple' || s.isDate) {
        value += 40;
      }
      if ((s.location ?? '').trim().isNotEmpty) {
        value += 20;
      }
      if (s.latitude != null && s.longitude != null) {
        value += 30;
      }
      return value;
    }

    final candidates = all.where((s) {
      final city = _extractCityFromLocation(s.location);
      return (s.latitude != null && s.longitude != null) || city != null;
    }).toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final byScore = score(b).compareTo(score(a));
      if (byScore != 0) return byScore;
      final aTime = (a.startTime?.hour ?? 99) * 60 + (a.startTime?.minute ?? 99);
      final bTime = (b.startTime?.hour ?? 99) * 60 + (b.startTime?.minute ?? 99);
      return aTime.compareTo(bTime);
    });

    final picked = candidates.first;
    final city = _extractCityFromLocation(picked.location);
    final label = (picked.location ?? '').trim().isNotEmpty
        ? picked.location!.trim()
        : (city ?? '일정 지역');

    return (
      label: label,
      city: city,
      lat: picked.latitude,
      lng: picked.longitude,
    );
  }

  Future<void> _loadScheduleWeatherForDate(
    CoupleProfile? profile,
    DateTime date,
  ) async {
    final requestSeq = ++_weatherRequestSeq;
    final targetDateKey = _dateKey(date);
    if (profile == null) {
      if (!mounted) return;
      setState(() {
        _myWeatherData = null;
        _partnerWeatherData = null;
        _schedulePlaceWeatherData = null;
        _myWeatherStatusText = null;
        _partnerWeatherStatusText = null;
        _schedulePlaceStatusText = null;
        _schedulePlaceLabel = null;
        _schedulePlaceCityForDetail = null;
        _isScheduleWeatherLoading = false;
        _activeWeatherDateKey = null;
      });
      return;
    }

    final myCity = profile.myCity?.trim();
    final partnerCity = profile.partnerCity?.trim();
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (mounted) {
      setState(() {
        _isScheduleWeatherLoading = true;
        _activeWeatherDateKey = targetDateKey;
        _myWeatherData = null;
        _partnerWeatherData = null;
        _schedulePlaceWeatherData = null;
        _myWeatherStatusText = null;
        _partnerWeatherStatusText = null;
        _schedulePlaceStatusText = null;
        _schedulePlaceLabel = null;
        _schedulePlaceCityForDetail = null;
      });
    }

    Future<({WeatherData? data, String? status})> loadOne(String? city) async {
      if (city == null || city.isEmpty) {
        return (data: null, status: '지역 설정 필요');
      }
      if (!cityCoordinates.containsKey(city)) {
        return (data: null, status: '도시 재선택 필요');
      }

      final dayDiff = normalizedDate.difference(today).inDays;
      if (dayDiff > 15) {
        return (data: null, status: '예보 범위 초과');
      }

      final forecast = await _weatherService.getWeatherForDate(city, normalizedDate);
      return forecast != null
          ? (data: forecast, status: null)
          : (data: null, status: '날씨 정보 없음');
    }

    final scheduleSource = _pickScheduleWeatherSource(normalizedDate);
    if (scheduleSource != null) {
      final dayDiff = normalizedDate.difference(today).inDays;
      if (dayDiff > 15) {
        if (!mounted || requestSeq != _weatherRequestSeq) return;
        setState(() {
          _schedulePlaceWeatherData = null;
          _schedulePlaceStatusText = '예보 범위 초과';
          _schedulePlaceLabel = '일정';
          _schedulePlaceCityForDetail = null;
          _isScheduleWeatherLoading = false;
          _activeWeatherDateKey = targetDateKey;
        });
        return;
      }

      WeatherData? scheduleData;
      if (scheduleSource.lat != null && scheduleSource.lng != null) {
        scheduleData = await _weatherService.getWeatherForDateByCoordinates(
          label: scheduleSource.label,
          latitude: scheduleSource.lat!,
          longitude: scheduleSource.lng!,
          date: normalizedDate,
        );
      } else if (scheduleSource.city != null) {
        scheduleData = await _weatherService.getWeatherForDate(
          scheduleSource.city!,
          normalizedDate,
        );
      }

      if (!mounted || requestSeq != _weatherRequestSeq) return;
      setState(() {
        _schedulePlaceWeatherData = scheduleData;
        _schedulePlaceStatusText = scheduleData == null ? '날씨 정보 없음' : null;
        _schedulePlaceLabel = '일정';
        _schedulePlaceCityForDetail = scheduleSource.city;
        _isScheduleWeatherLoading = false;
        _activeWeatherDateKey = targetDateKey;
      });
      return;
    }

    final myResult = await loadOne(myCity);
    final partnerResult =
        (partnerCity != null && partnerCity.isNotEmpty && partnerCity != myCity)
        ? await loadOne(partnerCity)
        : (data: null, status: null);

    if (!mounted || requestSeq != _weatherRequestSeq) return;
    setState(() {
      _myWeatherData = myResult.data;
      _partnerWeatherData = partnerResult.data;
      _myWeatherStatusText = myResult.status;
      _partnerWeatherStatusText = partnerResult.status;
      _schedulePlaceWeatherData = null;
      _schedulePlaceStatusText = null;
      _schedulePlaceLabel = null;
      _schedulePlaceCityForDetail = null;
      _isScheduleWeatherLoading = false;
      _activeWeatherDateKey = targetDateKey;
    });
  }

  String _weatherEmoji(int weatherCode) {
    if (weatherCode == 0) return '☀';
    if (weatherCode == 1 || weatherCode == 2) return '⛅';
    if (weatherCode == 3) return '☁';
    if (weatherCode >= 45 && weatherCode <= 48) return '🌫';
    if (weatherCode >= 51 && weatherCode <= 67) return '🌧';
    if (weatherCode >= 71 && weatherCode <= 77) return '❄';
    if (weatherCode >= 80 && weatherCode <= 82) return '🌦';
    if (weatherCode >= 85 && weatherCode <= 86) return '🌨';
    if (weatherCode >= 95) return '⛈';
    return '☁';
  }

  Widget _buildScheduleWeatherItem({
    required String label,
    required WeatherData? data,
    required String? statusText,
    required bool isLoading,
    VoidCallback? onTap,
    required Color chipColor,
    required Color borderColor,
    required Color textColor,
  }) {
    final weatherText = isLoading
        ? '날씨 준비 중'
        : (data != null
        ? '${data.city} ${data.temperature.round()}° ${_weatherEmoji(data.weatherCode)}'
        : (statusText ?? '날씨 정보 없음'));

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  weatherText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openWeatherDetail(
    DateTime dateTime, {
    required String city,
    required String roleLabel,
  }) {
    final trimmedCity = city.trim();
    if (trimmedCity.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('설정에서 지역을 먼저 입력해 주세요.')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeatherDetailScreen(
          date: dateTime,
          city: trimmedCity,
          roleLabel: roleLabel,
        ),
      ),
    );
  }

  Widget _buildScheduleWeatherRow({
    required String partnerName,
    required DateTime dateTime,
  }) {
    final showMy = _profile?.myCity != null && _profile!.myCity!.isNotEmpty;
    final showPartner =
        _profile?.partnerCity != null && _profile!.partnerCity!.isNotEmpty;

    final dateKey = _dateKey(dateTime);
    final todayKey = _dateKey(DateTime.now());
    final isToday = dateKey == todayKey;
    final hasRequested = _weatherRequestedDateKeys.contains(dateKey);

    if (!showMy && !showPartner) {
      return const SizedBox.shrink();
    }

    if (!isToday && !hasRequested) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isScheduleWeatherLoading
              ? null
              : () => _onTapScheduleWeatherFetch(dateTime),
          icon: const Icon(Icons.cloud_outlined, size: 16),
          label: const Text('날씨 조회'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primary,
            side: BorderSide(
              color: AppTheme.primary.withValues(alpha: 0.35),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      );
    }

    final chipColor = AppTheme.primary.withValues(alpha: 0.07);
    final borderColor = AppTheme.primary.withValues(alpha: 0.16);

    if (_schedulePlaceWeatherData != null || _schedulePlaceStatusText != null) {
      return Row(
        children: [
          _buildScheduleWeatherItem(
            label: _schedulePlaceLabel ?? '일정',
            data: _schedulePlaceWeatherData,
            statusText: _schedulePlaceStatusText,
            isLoading:
                _isScheduleWeatherLoading && _activeWeatherDateKey == dateKey,
            onTap: _schedulePlaceCityForDetail != null
                ? () => _openWeatherDetail(
                      dateTime,
                      city: _schedulePlaceCityForDetail!,
                      roleLabel: _schedulePlaceLabel ?? '일정',
                    )
                : null,
            chipColor: chipColor,
            borderColor: borderColor,
            textColor: AppTheme.primary,
          ),
        ],
      );
    }

    if (showMy && showPartner && _profile!.myCity != _profile!.partnerCity) {
      return Row(
        children: [
          _buildScheduleWeatherItem(
            label: '나',
            data: _myWeatherData,
            statusText: _myWeatherStatusText,
            isLoading: _isScheduleWeatherLoading && _activeWeatherDateKey == dateKey,
            onTap: () => _openWeatherDetail(
              dateTime,
              city: _profile?.myCity ?? '',
              roleLabel: '내',
            ),
            chipColor: chipColor,
            borderColor: borderColor,
            textColor: AppTheme.primary,
          ),
          const SizedBox(width: 8),
          _buildScheduleWeatherItem(
            label: partnerName,
            data: _partnerWeatherData,
            statusText: _partnerWeatherStatusText,
            isLoading: _isScheduleWeatherLoading && _activeWeatherDateKey == dateKey,
            onTap: () => _openWeatherDetail(
              dateTime,
              city: _profile?.partnerCity ?? '',
              roleLabel: partnerName,
            ),
            chipColor: chipColor,
            borderColor: borderColor,
            textColor: AppTheme.primary,
          ),
        ],
      );
    }

    final primaryData = _myWeatherData ?? _partnerWeatherData;
    final primaryLabel = showMy ? '나' : partnerName;
    final primaryCity = showMy ? (_profile?.myCity ?? '') : (_profile?.partnerCity ?? '');
    return Row(
      children: [
        _buildScheduleWeatherItem(
          label: primaryLabel,
          data: primaryData,
          statusText: primaryData == null ? (_myWeatherStatusText ?? _partnerWeatherStatusText) : null,
          isLoading: _isScheduleWeatherLoading && _activeWeatherDateKey == dateKey,
          onTap: () => _openWeatherDetail(
            dateTime,
            city: primaryCity,
            roleLabel: primaryLabel == '나' ? '내' : partnerName,
          ),
          chipColor: chipColor,
          borderColor: borderColor,
          textColor: AppTheme.primary,
        ),
      ],
    );
  }

  Future<void> _updateHomeWidget() async {
    final myList = _todaySchedules?['mine'] ?? [];
    final partnerList = _todaySchedules?['partner'] ?? [];
    String myWeather = '';
    String partnerWeather = '';
    final weatherSvc = WeatherService();
    if (_profile?.myCity != null) {
      final w = await weatherSvc.getWeather(_profile!.myCity!);
      if (w != null) {
        myWeather = HomeWidgetService.formatWeather(
          city: _profile!.myCity!,
          temperature: w.temperature,
          weatherCode: w.weatherCode,
        );
      }
    }
    if (_profile?.partnerCity != null) {
      final w = await weatherSvc.getWeather(_profile!.partnerCity!);
      if (w != null) {
        partnerWeather = HomeWidgetService.formatWeather(
          city: _profile!.partnerCity!,
          temperature: w.temperature,
          weatherCode: w.weatherCode,
        );
      }
    }
    String nextLabel = '';
    if (_nextDate != null) {
      final s = _nextDate!['schedule'] as Schedule;
      nextLabel = '${s.date.month}월 ${s.date.day}일';
    }
    await HomeWidgetService.updateWidget(
      dDays: _dDays ?? 0,
      partnerName: _partnerNickname ?? '애인',
      mySchedule: myList.isNotEmpty
          ? (myList.first.title ?? myList.first.category ?? '일정')
          : '쉬는날',
      partnerSchedule: partnerList.isNotEmpty
          ? (partnerList.first.title ?? partnerList.first.category ?? '일정')
          : '쉬는날',
      myWeather: myWeather,
      partnerWeather: partnerWeather,
      nextDateDays: _nextDateDaysUntil ?? -1,
      nextDateLabel: nextLabel,
    );
  }

  Future<void> _checkNotifications(Map<String, dynamic> data) async {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final nm = NotificationManager();
    final todaySchedules =
        data['today_schedules'] as Map<String, List<Schedule>>?;
    if (todaySchedules != null) {
      final allToday = <Schedule>[
        ...(todaySchedules['mine'] ?? []),
        ...(todaySchedules['partner'] ?? []),
      ];
      await nm.checkDateToday(schedules: allToday, today: today);
      final myTodaySchedules = todaySchedules['mine'] ?? [];
      final partnerTodaySchedules = todaySchedules['partner'] ?? [];

      final myOff = myTodaySchedules
          .where((s) => _isOffSchedule(s.category))
          .toList();
      final partnerOff = partnerTodaySchedules
          .where((s) => _isOffSchedule(s.category))
          .toList();

      if (myTodaySchedules.isEmpty) {
        myOff.add(
          Schedule(
            id: 'virtual_my_off_${_dateKey(today)}',
            userId: 'me',
            coupleId: _coupleId,
            date: DateTime(today.year, today.month, today.day),
            category: '쉬는날',
          ),
        );
      }
      if (partnerTodaySchedules.isEmpty) {
        partnerOff.add(
          Schedule(
            id: 'virtual_partner_off_${_dateKey(today)}',
            userId: 'partner',
            coupleId: _coupleId,
            date: DateTime(today.year, today.month, today.day),
            category: '쉬는날',
          ),
        );
      }

      if (myOff.isNotEmpty && partnerOff.isNotEmpty) {
        await nm.checkBothOffAndSchedule(
          mySchedules: myOff,
          partnerSchedules: partnerOff,
          today: today,
        );
      }
    }
    final tomorrowSchedules =
        data['tomorrow_schedules'] as Map<String, List<Schedule>>?;
    if (tomorrowSchedules != null) {
      final allTomorrow = <Schedule>[
        ...(tomorrowSchedules['mine'] ?? []),
        ...(tomorrowSchedules['partner'] ?? []),
      ];
      await nm.checkDateBefore(schedules: allTomorrow, tomorrow: tomorrow);
    }
  }

  // ─── Getters ─────────────────────────────────────────────────────────────────

  int? get _dDays => _data['d_days']?['days'] as int?;
  String? get _partnerNickname =>
      _data['d_days']?['partner_nickname'] as String?;
  Map<String, List<Schedule>>? get _todaySchedules =>
      _data['today_schedules'] as Map<String, List<Schedule>>?;
  Map<String, dynamic>? get _nextDate =>
      _data['next_date'] as Map<String, dynamic>?;
  int? get _nextDateDaysUntil => _data['next_date']?['days_until'] as int?;
  Map<String, dynamic>? get _lastDate =>
      _data['last_date'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _nextBothOff =>
      _data['next_both_off'] as Map<String, dynamic>?;
  String? get _relationshipStartDate =>
      _data['d_days']?['started_at'] as String?;

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DateTime _dateForPage(int page) {
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    return base.add(Duration(days: page - _kScheduleBasePage));
  }

  String _getSchedulePageDateLabel() {
    final date = _dateForPage(_schedulePage);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final tomorrow = todayDate.add(const Duration(days: 1));
    
    if (date == todayDate) {
      return '오늘';
    }
    if (date == tomorrow) {
      return '내일';
    }
    
    final days = ['월', '화', '수', '목', '금', '토', '일'];
    final dayOfWeek = days[date.weekday - 1];
    return '${date.year}.${date.month}.${date.day}($dayOfWeek)';
  }

  Future<void> _ensureSchedulesLoadedFor(DateTime date) async {
    if (_coupleId == null) return;

    final key = _dateKey(date);
    if (_scheduleByDate.containsKey(key) ||
        _scheduleLoadingDates.contains(key)) {
      return;
    }

    setState(() => _scheduleLoadingDates.add(key));
    try {
      final schedules = await _homeService.getSchedulesForDate(
        _coupleId!,
        date,
      );
      if (!mounted) return;
      setState(() => _scheduleByDate[key] = schedules);

      final activeDateKey = _dateKey(_dateForPage(_schedulePage));
      if (activeDateKey == key) {
        await _syncScheduleWeatherForDate(date);
      }
    } catch (_) {
      // Keep UI stable when per-day query fails.
    } finally {
      if (mounted) {
        setState(() => _scheduleLoadingDates.remove(key));
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _coupleId == null) {
      return _buildSkeletonLoading();
    }
    if (_coupleId == null) return _buildNoCoupleState();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final bgPhotoPath = _couplePhotoPath;
    final bgPhotoFile = bgPhotoPath == null ? null : File(bgPhotoPath);
    final hasCustomHeroPhoto = bgPhotoFile != null && bgPhotoFile.existsSync();
    final safeDefaultIndex = (_defaultHeroPreset ?? 0).clamp(
      0,
      _kDefaultHeroPresetAssets.length - 1,
    );
    final defaultAssetPath = _hasDefaultHeroPreset
        ? _kDefaultHeroPresetAssets[safeDefaultIndex]
        : null;
    final hasMainGlassBackground =
        _useHeroPhotoAsMainBackground &&
        (hasCustomHeroPhoto || _hasDefaultHeroPreset);

    return Stack(
      children: [
        Positioned.fill(
          child: hasMainGlassBackground
              ? (hasCustomHeroPhoto
                    ? _buildMainGlassBackground(bgPhotoFile)
                : _buildMainGlassBackgroundAsset(defaultAssetPath!))
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.accentLight,
                        AppTheme.background,
                        const Color(0xFFFFF7F5),
                      ],
                      stops: const [0.0, 0.48, 1.0],
                    ),
                  ),
                ),
        ),
        CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: topPad + 20)),
            SliverToBoxAdapter(child: _buildTopBar()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),
                    _buildHeroSection(),
                    const SizedBox(height: 16),
                    _buildDateInsightCarousel(),
                    const SizedBox(height: 24),
                    _buildTwoColSchedule(),
                    const SizedBox(height: 24),
                    _buildDateIdeasSection(),
                    SizedBox(height: bottomPad + 96),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool get _hasMainGlassBackgroundActive {
    if (!_useHeroPhotoAsMainBackground) {
      return false;
    }
    final path = _couplePhotoPath;
    if (path != null && File(path).existsSync()) {
      return true;
    }
    return _hasDefaultHeroPreset;
  }

  TextStyle _sectionEyebrowStyle({double letterSpacing = 2.2}) {
    if (_hasMainGlassBackgroundActive) {
      return GoogleFonts.gaegu(
        fontSize: 11,
        color: Colors.white,
        fontWeight: FontWeight.w700,
        letterSpacing: letterSpacing,
        shadows: const [
          Shadow(
            color: Color(0x8A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      );
    }
    return GoogleFonts.gaegu(
      fontSize: 11,
      color: AppTheme.textTertiary,
      fontWeight: FontWeight.w700,
      letterSpacing: letterSpacing,
    );
  }

  Widget _buildHeadingTextShell(
    String text, {
    required TextStyle style,
    EdgeInsetsGeometry? padding,
  }) {
    final label = Text(text, style: style);
    if (!_hasMainGlassBackgroundActive) {
      return label;
    }
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: label,
    );
  }

  List<Color> _glassCardSurfaceGradient() {
    if (!_hasMainGlassBackgroundActive) {
      return const [Color(0xFFFFFEFC), Color(0xFFF7F1EA)];
    }

    final safeDefaultIndex = (_defaultHeroPreset ?? 0).clamp(
      0,
      _kDefaultHeroPresetAssets.length - 1,
    );
    final tint = safeDefaultIndex == 1
        ? const Color(0xFFDDEBE1)
        : const Color(0xFFF2E8D9);

    return [
      Color.lerp(const Color(0xFFFFFFFF), tint, 0.18)!
          .withValues(alpha: 0.72),
      Color.lerp(const Color(0xFFF8F3EA), tint, 0.12)!
          .withValues(alpha: 0.54),
    ];
  }

  Color _glassCardBorderColor({double alpha = 0.42}) =>
      Colors.white.withValues(alpha: alpha);

  List<BoxShadow> _glassCardShadows() {
    return const <BoxShadow>[];
  }

  BoxDecoration? _glassCardSheenDecoration(double radius) {
    if (!_hasMainGlassBackgroundActive) return null;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.26),
          Colors.white.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 0.34, 0.82],
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    final today = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[today.weekday - 1];
    final holidays = HolidayService().getHolidays(today);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COUPLEDUTY',
                  style: _sectionEyebrowStyle(),
                ),
              ],
            ),
          ),
          if (holidays.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accentLight,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.border, width: 1),
              ),
              child: Text(
                holidays.first.name,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          _TopBarIconButton(
            label: '${today.month}.${today.day} ($weekday)',
            icon: Icons.calendar_today_outlined,
            onTap: null,
          ),
          const SizedBox(width: 8),
          _TopBarIconButton(
            icon: Icons.calendar_month_rounded,
            onTap: () => _openScreen(const CalendarScreen()),
          ),
          const SizedBox(width: 8),
          _TopBarIconButton(
            icon: Icons.notifications_rounded,
            onTap: () => _openScreen(const NotificationHistoryScreen()),
          ),
          const SizedBox(width: 8),
          _TopBarIconButton(
            icon: Icons.settings_rounded,
            onTap: () => _openScreen(const SettingsScreen()),
          ),
        ],
      ),
    );
  }

  void _openScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // ── Hero Section ────────────────────────────────────────────────────────────

  Widget _buildHeroSection() {
    DateTime? startedAt;
    String startDateLabel = '';
    final photoPath = _couplePhotoPath;
    final photoFile = photoPath == null ? null : File(photoPath);
    final hasHeroPhoto = photoFile != null && photoFile.existsSync();
    final hasDefaultHeroBackground = !hasHeroPhoto && _hasDefaultHeroPreset;
    final hasHeroVisual = hasHeroPhoto || hasDefaultHeroBackground;
    final isPaperTicketMode = !hasHeroVisual;
    // 배경 없음에서도 컴팩트 레이아웃은 유지하되, 티켓 카피를 추가해 비어 보임을 줄임
    final compactPhotoMode = hasHeroVisual || _coupleId != null;
    final heroPaperGradient = isPaperTicketMode
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFCF8), Color(0xFFF6EFE6)],
            stops: [0.0, 1.0],
          )
        : null;
    final heroSurfaceColor = _hasMainGlassBackgroundActive && !hasHeroPhoto
      ? AppTheme.surface.withValues(alpha: 0.76)
      : AppTheme.surface;
    final heroBorderColor = isPaperTicketMode
        ? const Color(0xFFE5D8CB)
        : _hasMainGlassBackgroundActive
        ? Colors.white.withValues(alpha: 0.30)
        : AppTheme.border;
    final titleColor = hasHeroVisual ? Colors.white : AppTheme.textPrimary;
    final bodyColor = hasHeroVisual
        ? Colors.white.withValues(alpha: 0.92)
        : AppTheme.textSecondary;
    final captionColor = hasHeroVisual
        ? Colors.white.withValues(alpha: 0.9)
        : AppTheme.textSecondary;

    if (_relationshipStartDate != null) {
      try {
        startedAt = DateTime.parse(_relationshipStartDate!);
        startDateLabel =
            'Starting on ${_monthEn(startedAt.month)} ${startedAt.day}, ${startedAt.year}';
      } catch (_) {}
    }

    return GestureDetector(
      onTap: startedAt == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RelationshipTimelineScreen(
                  startedAt: startedAt!,
                  myNickname: null,
                  partnerNickname: _partnerNickname,
                ),
              ),
            ),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: _kHeroAspectRatio,
            child: Container(
              decoration: BoxDecoration(
                color: heroSurfaceColor,
                gradient: heroPaperGradient,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: heroBorderColor),
                boxShadow: const [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    if (hasHeroPhoto)
                      Positioned.fill(child: _buildHeroBackgroundImage(photoFile)),
                    if (hasDefaultHeroBackground)
                      Positioned.fill(child: _buildDefaultHeroBackdrop()),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: hasHeroVisual
                              ? LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.06),
                                    Colors.black.withValues(alpha: 0.36),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),
                    if (_hasMainGlassBackgroundActive)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.18),
                                Colors.white.withValues(alpha: 0.08),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        mainAxisAlignment: compactPhotoMode
                            ? MainAxisAlignment.spaceBetween
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: hasHeroVisual
                                            ? Colors.black.withValues(alpha: 0.34)
                                            : AppTheme.primary.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: hasHeroVisual
                                              ? Colors.white.withValues(alpha: 0.26)
                                              : AppTheme.primary.withValues(alpha: 0.34),
                                        ),
                                      ),
                                      child: Text(
                                        isPaperTicketMode
                                          ? 'OUR DAY'
                                            : _partnerNickname != null
                                            ? '${_partnerNickname!}${_selectKoreanParticle(text: _partnerNickname!, consonant: '과', vowel: '와')} 함께한 소중한 시간 🤍'
                                            : '우리가 함께한 소중한 시간 🤍',
                                        style: GoogleFonts.gaegu(
                                          fontSize: isPaperTicketMode ? 13 : 14,
                                          color: hasHeroVisual
                                              ? Colors.white
                                              : AppTheme.primary,
                                          fontWeight: isPaperTicketMode
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          letterSpacing: isPaperTicketMode
                                              ? 0.6
                                              : 0.2,
                                        ),
                                      ),
                                    ),
                                    if (isPaperTicketMode) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        _partnerNickname == null
                                            ? '함께 쌓아온 시간, 오늘도 차곡차곡'
                                            : '${_partnerNickname!}${_selectKoreanParticle(text: _partnerNickname!, consonant: '과', vowel: '와')} 함께 쌓아온 시간, 오늘도 차곡차곡',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.gaegu(
                                          fontSize: 19,
                                          color: const Color(0xFF5C4A3A),
                                          fontWeight: FontWeight.w700,
                                          height: 1.15,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: 132,
                                        height: 1,
                                        color: const Color(0xFFD9CCBE),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        startDateLabel.isNotEmpty
                                            ? startDateLabel
                                            : '연애 시작일을 기준으로 D+DAY를 계산하고 있어요.',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.gaegu(
                                          fontSize: 12,
                                          color: const Color(0xFF7A6755),
                                          fontWeight: FontWeight.w600,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                    if (!compactPhotoMode) ...[
                                      const SizedBox(height: 16),
                                      Text(
                                        _partnerNickname == null
                                            ? '함께 쌓아온 시간'
                                            : '${_partnerNickname!}${_selectKoreanParticle(text: _partnerNickname!, consonant: '과', vowel: '와')} 함께 쌓아온 시간',
                                        style: GoogleFonts.gaegu(
                                          textStyle: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                color: titleColor,
                                                fontWeight: FontWeight.w700,
                                                height: 1.2,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        startDateLabel.isNotEmpty
                                            ? startDateLabel
                                            : '연애 시작일을 기준으로 D-day를 계산하고 있어요.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: bodyColor,
                                              height: 1.5,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: compactPhotoMode ? 0 : 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (isPaperTicketMode)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '같은 하루를 바라본 지',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.gaegu(
                                        fontSize: 13,
                                        color: const Color(0xFF8A7765),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              if (!compactPhotoMode) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '같은 하루를 바라본 지',
                                    style: GoogleFonts.gaegu(
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: captionColor),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Text(
                                _dDays != null ? 'D+${_dDays!}' : 'D+--',
                                style: GoogleFonts.gaegu(
                                  fontSize: 46,
                                  color: titleColor,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.6,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: hasHeroPhoto
                  ? Colors.black.withValues(alpha: 0.28)
                  : hasDefaultHeroBackground
                    ? Colors.black.withValues(alpha: 0.20)
                    : AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                  color: hasHeroVisual
                      ? Colors.white.withValues(alpha: 0.28)
                      : AppTheme.border,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: hasHeroPhoto
                    ? _editCurrentCouplePhoto
                    : _showHeroBackgroundOptionsSheet,
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(
                    Icons.settings,
                    size: 18,
                    color: hasHeroVisual ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBackgroundImage(File file) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final cacheWidth = width.isFinite ? width.round() * 2 : 1600;
        final cacheHeight = height.isFinite ? height.round() * 2 : 1053;

        return Transform(
          transform: Matrix4.identity()
            ..translate(_heroPhotoOffset.dx, _heroPhotoOffset.dy)
            ..translate(width / 2, height / 2)
            ..scale(_heroPhotoScale)
            ..translate(-width / 2, -height / 2),
          child: SizedBox.expand(
            child: Image.file(
              file,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              filterQuality: FilterQuality.low,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultHeroBackdrop() {
    final safeIndex = (_defaultHeroPreset ?? 0).clamp(
      0,
      _kDefaultHeroPresetAssets.length - 1,
    );
    final assetPath = _kDefaultHeroPresetAssets[safeIndex];

    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) => const _DefaultHeroBackdrop(),
    );
  }

  Widget _buildMainGlassBackground(File file) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final cacheWidth = width.isFinite ? width.round() * 2 : 1600;
        final cacheHeight = height.isFinite ? height.round() * 2 : 3000;

        return Stack(
          fit: StackFit.expand,
          children: [
            Transform(
              transform: Matrix4.identity()
                ..translate(_heroPhotoOffset.dx, _heroPhotoOffset.dy)
                ..translate(width / 2, height / 2)
                ..scale(_heroPhotoScale)
                ..translate(-width / 2, -height / 2),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  cacheWidth: cacheWidth,
                  cacheHeight: cacheHeight,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accentLight.withValues(alpha: 0.34),
                    AppTheme.background.withValues(alpha: 0.24),
                    const Color(0xFFFFF7F5).withValues(alpha: 0.22),
                  ],
                  stops: const [0.0, 0.52, 1.0],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.22),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.12),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainGlassBackgroundAsset(String assetPath) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.low,
                cacheWidth: width.isFinite ? width.round() * 2 : null,
                cacheHeight: height.isFinite ? height.round() * 2 : null,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accentLight.withValues(alpha: 0.34),
                    AppTheme.background.withValues(alpha: 0.24),
                    const Color(0xFFFFF7F5).withValues(alpha: 0.22),
                  ],
                  stops: const [0.0, 0.52, 1.0],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.22),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.12),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _monthEn(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[m - 1];
  }

  // ── Date Insight Carousel ─────────────────────────────────────────────────

  Map<String, dynamic>? _getNextAnniversaryInfo() {
    final startedAtRaw = _relationshipStartDate;
    if (startedAtRaw == null) return null;

    DateTime startedAt;
    try {
      startedAt = DateTime.parse(startedAtRaw);
    } catch (_) {
      return null;
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final candidates = <Map<String, dynamic>>[];

    for (int i = 1; i <= 10; i++) {
      final annivDate = startedAt.add(Duration(days: i * 100 - 1));
      final dateOnly = DateTime(annivDate.year, annivDate.month, annivDate.day);
      if (!dateOnly.isBefore(todayDate)) {
        candidates.add({
          'title': '${i * 100}일',
          'date': dateOnly,
          'daysUntil': dateOnly.difference(todayDate).inDays,
        });
      }
    }

    for (int i = 1; i <= 10; i++) {
      final annivDate = DateTime(startedAt.year + i, startedAt.month, startedAt.day);
      final dateOnly = DateTime(annivDate.year, annivDate.month, annivDate.day);
      if (!dateOnly.isBefore(todayDate)) {
        candidates.add({
          'title': '$i주년',
          'date': dateOnly,
          'daysUntil': dateOnly.difference(todayDate).inDays,
        });
      }
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => (a['daysUntil'] as int).compareTo(b['daysUntil'] as int));
    return candidates.first;
  }

  String _formatKoreanDate(DateTime date) => '${date.month}월 ${date.day}일';

  Widget _buildDateInsightCarousel() {
    final nextDateInfo = _nextDate;
    final nextDateDaysUntil = _nextDateDaysUntil;
    DateTime? nextDate;
    String nextDateSub = '일정을 등록해 두면 여기에 보여요';

    if (nextDateInfo != null) {
      try {
        final s = nextDateInfo['schedule'] as Schedule;
        nextDate = s.date;
        nextDateSub = _formatKoreanDate(nextDate);
      } catch (_) {}
    }

    final nextDateValue = nextDateDaysUntil == null
        ? '없음'
        : nextDateDaysUntil == 0
        ? '오늘'
        : nextDateDaysUntil == 1
        ? '내일'
        : 'D-$nextDateDaysUntil';

    final lastDateInfo = _lastDate;
    DateTime? lastDate;
    int? lastDateDaysSince;
    if (lastDateInfo != null) {
      try {
        final s = lastDateInfo['schedule'] as Schedule;
        final effectiveDate = lastDateInfo['last_met_date'] as DateTime?;
        final fallbackDate = s.endDate ?? s.date;
        lastDate = effectiveDate ?? fallbackDate;
        lastDateDaysSince = lastDateInfo['days_since'] as int?;
      } catch (_) {}
    }

    final lastDateValue = lastDateDaysSince == null
        ? '기록 없음'
        : lastDateDaysSince == 0
        ? '오늘'
        : 'D+$lastDateDaysSince';
    final lastDateSub = lastDate == null
        ? '첫 데이트를 기다리는 중'
        : '마지막: ${_formatKoreanDate(lastDate)}';

    final nextAnniversary = _getNextAnniversaryInfo();
    final anniversaryDate = nextAnniversary?['date'] as DateTime?;
    final anniversaryDaysUntil = nextAnniversary?['daysUntil'] as int?;
    final anniversaryTitle = (nextAnniversary?['title'] as String?) ?? '예정 없음';
    final anniversaryValue = anniversaryDaysUntil == null
        ? '--'
        : anniversaryDaysUntil == 0
        ? '오늘'
        : 'D-$anniversaryDaysUntil';
    final anniversarySub = anniversaryDate == null
        ? '기념일 정보를 계산할 수 없어요'
        : '${_formatKoreanDate(anniversaryDate)} · $anniversaryTitle';

    final cards = <_DateInsightCardData>[
      _DateInsightCardData(
        title: '마지막 데이트',
        value: lastDateValue,
        subtitle: lastDateSub,
        icon: Icons.history_rounded,
        iconColor: AppTheme.accent,
        bgColor: AppTheme.surface,
        onTap: lastDate == null
            ? null
            : () => _openScreen(CalendarScreen(initialDate: lastDate)),
      ),
      _DateInsightCardData(
        title: '다음 데이트',
        value: nextDateValue,
        subtitle: nextDateSub,
        icon: Icons.calendar_today_outlined,
        iconColor: AppTheme.primary,
        bgColor: AppTheme.surface,
        onTap: nextDate == null
            ? null
            : () => _openScreen(CalendarScreen(initialDate: nextDate)),
      ),
      _DateInsightCardData(
        title: '다음 기념일',
        value: anniversaryValue,
        subtitle: anniversarySub,
        icon: Icons.celebration_outlined,
        iconColor: const Color(0xFFDB7A9A),
        bgColor: AppTheme.surface,
        onTap: anniversaryDate == null
            ? null
            : () => _openScreen(CalendarScreen(initialDate: anniversaryDate)),
      ),
      _DateInsightCardData(
        title: '함께 쉬는 날',
        value: () {
          final bothOff = _nextBothOff;
          if (bothOff == null) return '없음';
          final days = bothOff['days_until'] as int;
          if (days == 0) return '오늘!';
          if (days == 1) return '내일';
          return 'D-$days';
        }(),
        subtitle: () {
          final bothOff = _nextBothOff;
          if (bothOff == null) return '휴무 일정을 등록해 보세요';
          final d = bothOff['date'] as DateTime;
          return '${_formatKoreanDate(d)} 함께 쉬어요';
        }(),
        icon: Icons.wb_sunny_outlined,
        iconColor: const Color(0xFFF0954A),
        bgColor: AppTheme.surface,
        onTap: () => _openScreen(const CalendarScreen()),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        SizedBox(
          height: 164,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _buildDateInsightCard(cards[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildDateInsightCard(_DateInsightCardData card) {
    final surfaceGradient = _glassCardSurfaceGradient();
    final borderColor = _hasMainGlassBackgroundActive
        ? _glassCardBorderColor()
        : const Color(0xFFE7DCD1);

    return SizedBox(
      width: _kDateInsightCardWidth,
      child: GestureDetector(
        onTap: card.onTap,
        child: Stack(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: surfaceGradient,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
                boxShadow: _glassCardShadows(),
              ),
              foregroundDecoration: _glassCardSheenDecoration(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: card.iconColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: card.iconColor.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Text(
                          _ticketTag(card.title),
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.6,
                            color: card.iconColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        card.icon,
                        size: 18,
                        color: card.iconColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: const Color(0xFFDCCFC2),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    card.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _ticketCopy(card.title, card.subtitle),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.28,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ticketTag(String title) {
    switch (title) {
      case '다음 데이트':
        return 'NEXT';
      case '마지막 데이트':
        return 'MEMORY';
      case '다음 기념일':
        return 'ANNIV';
      case '함께 쉬는 날':
        return 'OFF';
      default:
        return 'DATE';
    }
  }

  String _ticketCopy(String title, String fallback) {
    switch (title) {
      case '다음 데이트':
        return '곧 만나서 오늘 얘기를 나눠요';
      case '마지막 데이트':
        return '지난 만남의 온기가 아직 남아있어요';
      case '다음 기념일':
        return '우리의 다음 챕터를 준비해볼까요';
      case '함께 쉬는 날':
        return '둘 다 쉬는 날, 느긋한 하루 예약';
      default:
        return fallback;
    }
  }

  // ── Date Ideas Section ───────────────────────────────────────────────────────

  List<_HomeFeatureCardData> _buildFeatureCards() {
    return [
      _HomeFeatureCardData(
        icon: Icons.train_outlined,
        title: '교통편 검색',
        subtitle: '기존 기능',
        gradientColors: const [Color(0xFF5378D8), Color(0xFF324B92)],
        onTap: _openTransportSearch,
      ),
      _HomeFeatureCardData(
        icon: Icons.place_outlined,
        title: '중간지역 검색',
        subtitle: '기존 기능',
        gradientColors: const [Color(0xFF19A39A), Color(0xFF0D6A64)],
        onTap: _openMidpointSearch,
      ),
      _HomeFeatureCardData(
        icon: Icons.auto_awesome_outlined,
        title: '데이트 추천',
        subtitle: '새로운 기능',
        gradientColors: const [Color(0xFFA864C9), Color(0xFF6E3E9C)],
        onTap: _openDateRecommendation,
      ),
    ];
  }

  void _openTransportSearch() {
    _openScreen(TransportSearchScreen(
      fromStation: _profile?.myStation,
      toStation: _profile?.partnerStation,
    ));
  }

  void _openMidpointSearch() {
    _openScreen(const MidpointSearchScreen());
  }

  void _openDateRecommendation() {
    _openScreen(
      DateRecommendationScreen(
        myCity: _profile?.myCity,
        partnerCity: _profile?.partnerCity,
        isLongDistance: _profile?.distanceType == 'long_distance',
      ),
    );
  }

  Widget _buildDateIdeasSection() {
    final featureCards = _buildFeatureCards();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeadingTextShell(
          'DATE TOOLS',
          style: _sectionEyebrowStyle().copyWith(
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: featureCards.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _buildFeatureCard(featureCards[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(_HomeFeatureCardData feature) {
    final surfaceGradient = _glassCardSurfaceGradient();
    final borderColor = _hasMainGlassBackgroundActive
        ? _glassCardBorderColor()
        : const Color(0xFFE7DCD1);

    return GestureDetector(
      onTap: feature.onTap,
      child: SizedBox(
        width: 146,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: surfaceGradient,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
                boxShadow: _glassCardShadows(),
              ),
              foregroundDecoration: _glassCardSheenDecoration(14),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: feature.gradientColors.first.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: feature.gradientColors.first.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Text(
                            feature.subtitle == '새로운 기능' ? 'NEW' : 'CORE',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 0.6,
                              color: feature.gradientColors.last,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          feature.icon,
                          size: 18,
                          color: feature.gradientColors.last,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: const Color(0xFFDCCFC2),
                    ),
                    const Spacer(),
                    Text(
                      feature.title,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      feature.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            ],
        ),
      ),
    );
  }

  // ── Two-Column Schedule ──────────────────────────────────────────────────────

  Widget _buildTwoColSchedule() {
    final isTodayPage = _schedulePage == _kScheduleBasePage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildHeadingTextShell(
              'SCHEDULE',
              style: _sectionEyebrowStyle(letterSpacing: 1.4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
            const Spacer(),
            GestureDetector(
              onTap: isTodayPage
                  ? null
                  : () {
                      _schedulePageController.animateToPage(
                        _kScheduleBasePage,
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                      );
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isTodayPage ? AppTheme.accentLight : AppTheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _getSchedulePageDateLabel(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isTodayPage ? AppTheme.textSecondary : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: _scheduleCardHeight(),
          child: PageView.builder(
            controller: _schedulePageController,
            onPageChanged: (page) {
              setState(() => _schedulePage = page);
              _ensureSchedulesLoadedFor(_dateForPage(page + 1));
              _syncScheduleWeatherForDate(_dateForPage(page));
            },
            itemBuilder: (context, pageIndex) {
              final date = _dateForPage(pageIndex);
              final dateKey = _dateKey(date);
              final daySchedules = _scheduleByDate[dateKey];
              final isLoading = _scheduleLoadingDates.contains(dateKey);

              if (daySchedules == null && !isLoading) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _ensureSchedulesLoadedFor(date);
                  }
                });
              }

              return AnimatedBuilder(
                animation: _schedulePageController,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _buildScheduleDayPage(
                    date: date,
                    schedules: daySchedules,
                    isLoading: isLoading,
                  ),
                ),
                builder: (context, child) {
                  final page = _schedulePageController.hasClients
                      ? (_schedulePageController.page ??
                          _schedulePage.toDouble())
                      : _schedulePage.toDouble();
                  final delta = (page - pageIndex).abs();
                  final signedDelta = (page - pageIndex).clamp(-1.0, 1.0);
                    final clampedDelta = delta.clamp(0.0, 1.0);
                    final easedMagnitude =
                      Curves.easeOutCubic.transform(clampedDelta);
                  final easedSigned = signedDelta < 0
                      ? -Curves.easeOutCubic.transform(signedDelta.abs())
                      : Curves.easeOutCubic.transform(signedDelta.abs());

                  final scale = (1 - (easedMagnitude * 0.2)).clamp(0.8, 1.0);
                  final yOffset = (1 - scale) * 12;
                  final rotateY = easedSigned * 0.56;
                  final xParallax = easedSigned * 18;

                  final matrix = Matrix4.identity()
                    ..setEntry(3, 2, 0.0016)
                    ..translate(xParallax)
                    ..rotateY(rotateY);

                  return Transform.translate(
                    offset: Offset(0, yOffset),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: matrix,
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.center,
                        child: child,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  double _scheduleCardHeight() {
    final date = _dateForPage(_schedulePage);
    final dateKey = _dateKey(date);
    final daySchedules = _scheduleByDate[dateKey];

    final mySchedules =
        (daySchedules?['mine'] ?? []).where((s) => s.ownerType != 'couple').toList();
    final partnerSchedules =
        (daySchedules?['partner'] ?? []).where((s) => s.ownerType != 'couple').toList();
    final sharedSchedules = <String, Schedule>{};
    for (final s in [
      ...(daySchedules?['mine'] ?? []),
      ...(daySchedules?['partner'] ?? []),
    ]) {
      if (s.ownerType == 'couple') sharedSchedules[s.id] = s;
    }

    final allSchedules = [
      ...mySchedules,
      ...partnerSchedules,
      ...sharedSchedules.values,
    ];

    final hasAnniversaryOrOff =
        (_getAnniversaryLabelFromSchedules(allSchedules) ??
                _getSystemAnniversaryLabel(date)) !=
            null ||
        (_isOffDay([...mySchedules, ...sharedSchedules.values]) &&
            _isOffDay([...partnerSchedules, ...sharedSchedules.values]));

    final hasWeather = (_profile?.myCity?.isNotEmpty ?? false) ||
        (_profile?.partnerCity?.isNotEmpty ?? false);

    final hasShared = sharedSchedules.isNotEmpty;
    final hasPersonal = mySchedules.isNotEmpty || partnerSchedules.isNotEmpty;

    // 최대 콘텐츠 아이템 수로 높이 결정
    final maxPersonalItems =
        (mySchedules.length > partnerSchedules.length ? mySchedules.length : partnerSchedules.length)
            .clamp(0, 4);
    final sharedItems = sharedSchedules.length.clamp(0, 3);

    double height = 248;
    if (hasAnniversaryOrOff) height += 38; // 칩 영역
    if (hasWeather && hasShared && hasPersonal) height += 24; // 여유 공간
    if (hasShared && hasPersonal) height += (sharedItems - 1).clamp(0, 2) * 28.0;
    if (hasPersonal) height += (maxPersonalItems - 1).clamp(0, 3) * 28.0;

    return height.clamp(248, 420);
  }

  Widget _buildScheduleDayPage({
    required DateTime date,
    required Map<String, List<Schedule>>? schedules,
    required bool isLoading,
  }) {
    final mySchedules = schedules?['mine'] ?? [];
    final partnerSchedules = schedules?['partner'] ?? [];

    final sharedById = <String, Schedule>{};
    for (final schedule in [...mySchedules, ...partnerSchedules]) {
      if (schedule.ownerType == 'couple') {
        sharedById[schedule.id] = schedule;
      }
    }

    final sharedSchedules = sharedById.values.toList();
    final myPersonalSchedules =
        mySchedules.where((s) => s.ownerType != 'couple').toList();
    final partnerPersonalSchedules =
        partnerSchedules.where((s) => s.ownerType != 'couple').toList();

    final allSchedules = [
      ...myPersonalSchedules,
      ...partnerPersonalSchedules,
      ...sharedSchedules,
    ];
    final partnerName = _partnerNickname ?? '애인';
    final anniversaryLabel = _getAnniversaryLabelFromSchedules(allSchedules) ??
        _getSystemAnniversaryLabel(date);
    final hasAnniversary = anniversaryLabel != null;
    // 디자인 우선순위는 기념일, 문구는 겹치면 함께 노출
    final bothOff = _isOffDay([...myPersonalSchedules, ...sharedSchedules]) &&
        _isOffDay([...partnerPersonalSchedules, ...sharedSchedules]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: isLoading && schedules == null
                ? _buildScheduleLoadingRow(date)
                : _buildUnifiedScheduleCard(
                    dateTime: date,
                    partnerName: partnerName,
                    sharedSchedules: sharedSchedules,
                    mySchedules: myPersonalSchedules,
                    partnerSchedules: partnerPersonalSchedules,
                    showBothOffText: bothOff,
                    showAnniversaryText: hasAnniversary,
                    anniversaryLabel: anniversaryLabel,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleLoadingRow(DateTime date) {
    return _buildUnifiedScheduleCard(
      dateTime: date,
      partnerName: _partnerNickname ?? '애인',
      sharedSchedules: const [],
      mySchedules: const [],
      partnerSchedules: const [],
      isLoading: true,
    );
  }

  Widget _buildUnifiedScheduleCard({
    required DateTime dateTime,
    required String partnerName,
    required List<Schedule> sharedSchedules,
    required List<Schedule> mySchedules,
    required List<Schedule> partnerSchedules,
    bool isLoading = false,
    bool showBothOffText = false,
    bool showAnniversaryText = false,
    String? anniversaryLabel,
  }) {
    final ticketColors = showAnniversaryText
        ? const [Color(0xFFFFFCF3), Color(0xFFFCEFD8)]
        : showBothOffText
        ? const [Color(0xFFFFFCFB), Color(0xFFF9EEF0)]
        : const [Color(0xFFFFFEFC), Color(0xFFF7F1EA)];
    final ticketBorderColor = showAnniversaryText
        ? const Color(0xFFE9D1A1)
        : showBothOffText
        ? const Color(0xFFECCED3)
        : const Color(0xFFE7DCD1);
    final effectiveTicketColors = _hasMainGlassBackgroundActive
      ? [
          Color.lerp(ticketColors[0], Colors.white, 0.08)!
              .withValues(alpha: 0.64),
          Color.lerp(ticketColors[1], const Color(0xFFECE2D7), 0.10)!
              .withValues(alpha: 0.54),
        ]
      : ticketColors;
    final effectiveTicketBorderColor = _hasMainGlassBackgroundActive
      ? _glassCardBorderColor(alpha: showAnniversaryText ? 0.44 : 0.40)
      : ticketBorderColor;
    final dividerColor = showAnniversaryText
        ? const Color(0xFFE2CCA2)
        : showBothOffText
        ? const Color(0xFFE6D5D8)
        : const Color(0xFFDCCFC2);
    final effectiveDividerColor = _hasMainGlassBackgroundActive
      ? Colors.white.withValues(alpha: 0.32)
      : dividerColor;
    final hasSharedSchedules = sharedSchedules.isNotEmpty;
    final hasPersonalSchedules =
        mySchedules.isNotEmpty || partnerSchedules.isNotEmpty;
    final ticketShadows = !_hasMainGlassBackgroundActive
        ? const <BoxShadow>[]
        : showAnniversaryText
        ? const [
            BoxShadow(
              color: Color(0x20DDAA4F),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ]
        : showBothOffText
        ? const [
            BoxShadow(
              color: Color(0x14E07A84),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 7,
              offset: Offset(0, 2),
            ),
          ]
        : const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ];
    final effectiveTicketShadows = _hasMainGlassBackgroundActive
        ? _glassCardShadows()
        : ticketShadows;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CalendarScreen(initialDate: dateTime),
        ),
      ),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: effectiveTicketColors,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: effectiveTicketBorderColor),
              boxShadow: effectiveTicketShadows,
            ),
            foregroundDecoration: _glassCardSheenDecoration(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showAnniversaryText || showBothOffText) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (showAnniversaryText)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9EBCB),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFE2CCA2),
                            ),
                          ),
                          child: Text(
                            '🎉 ${anniversaryLabel ?? '기념일'}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB37C1F),
                            ),
                          ),
                        ),
                      if (showBothOffText)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Text(
                            '둘다 휴무',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary.withValues(alpha: 0.92),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: effectiveDividerColor,
                  ),
                  const SizedBox(height: 6),
                ],
                _buildScheduleWeatherRow(
                  partnerName: partnerName,
                  dateTime: dateTime,
                ),
                if ((_profile?.myCity != null && _profile!.myCity!.isNotEmpty) ||
                    (_profile?.partnerCity != null &&
                        _profile!.partnerCity!.isNotEmpty)) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: effectiveDividerColor,
                  ),
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: hasSharedSchedules
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              fit: FlexFit.loose,
                              child: _buildScheduleSection(
                                label: '우리',
                                schedules: sharedSchedules,
                                emptyText: isLoading
                                    ? '불러오는 중...'
                                    : (showAnniversaryText ? '기념일' : '쉬는날'),
                              ),
                            ),
                            if (hasPersonalSchedules) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                height: 1,
                                color: effectiveDividerColor,
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _buildScheduleSection(
                                        label: '나',
                                        schedules: mySchedules,
                                        emptyText: isLoading
                                            ? '불러오는 중...'
                                            : (showAnniversaryText
                                                  ? '기념일'
                                                  : '일정 없음'),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      color: effectiveDividerColor,
                                    ),
                                    Expanded(
                                      child: _buildScheduleSection(
                                        label: partnerName,
                                        schedules: partnerSchedules,
                                        emptyText: isLoading
                                            ? '불러오는 중...'
                                            : (showAnniversaryText
                                                  ? '기념일'
                                                  : '일정 없음'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildScheduleSection(
                                label: '나',
                                schedules: mySchedules,
                                emptyText: isLoading
                                    ? '불러오는 중...'
                                    : (showAnniversaryText ? '기념일' : '쉬는날'),
                              ),
                            ),
                            Container(
                              width: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                              color: effectiveDividerColor,
                            ),
                            Expanded(
                              child: _buildScheduleSection(
                                label: partnerName,
                                schedules: partnerSchedules,
                                emptyText: isLoading
                                    ? '불러오는 중...'
                                    : (showAnniversaryText ? '기념일' : '쉬는날'),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection({
    required String label,
    required List<Schedule> schedules,
    required String emptyText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 9),
        Expanded(
          child: schedules.isEmpty
              ? Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    emptyText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              : ListView.separated(
                  primary: false,
                  padding: EdgeInsets.zero,
                  physics: const ClampingScrollPhysics(),
                  itemCount: schedules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final s = schedules[index];
                    final timeStr = s.startTime != null
                        ? '${s.startTime!.hour.toString().padLeft(2, '0')}:${s.startTime!.minute.toString().padLeft(2, '0')}'
                        : '';
                    final isAnniversary =
                        s.isAnniversary || s.category == '기념일';
                    final catColor = _categoryColor(s.category);
                    final displayTitle = s.title ?? s.category ?? '일정';

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: catColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAnniversary ? '🎉 $displayTitle' : displayTitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isAnniversary
                                      ? const Color(0xFFB4812E)
                                      : AppTheme.textPrimary,
                                  fontWeight: isAnniversary
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  height: 1.35,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (s.category != null || timeStr.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    [
                                      if (s.category != null) s.category!,
                                      if (timeStr.isNotEmpty) timeStr,
                                    ].join(' · '),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              if (s.location != null && s.location!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 11,
                                        color: AppTheme.textTertiary,
                                      ),
                                      const SizedBox(width: 2),
                                      Expanded(
                                        child: Text(
                                          s.location!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textTertiary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _categoryColor(String? category) {
    switch (category) {
      case '근무':
        return const Color(0xFFFF6B6B);
      case '야간':
        return const Color(0xFF6B9FFF);
      case '휴무':
        return const Color(0xFF4CAF7D);
      case '쉬는날':
        return const Color(0xFF4CAF7D);
      case '데이트':
        return AppTheme.primary;
      case '약속':
        return AppTheme.accent;
      case '여행':
        return const Color(0xFF6FAE9A);
      case '기념일':
        return const Color(0xFFC99A3A);
      default:
        return const Color(0xFFC9C1B8);
    }
  }

  bool _isOffSchedule(String? category) =>
      category == '휴무' || category == '쉬는날';

  bool _isOffDay(List<Schedule> schedules) {
    if (schedules.isEmpty) return true;
    return schedules.any((s) => _isOffSchedule(s.category));
  }

  String? _getAnniversaryLabelFromSchedules(List<Schedule> schedules) {
    for (final s in schedules) {
      if (s.isAnniversary || s.category == '기념일') {
        return s.title ?? '기념일';
      }
    }
    return null;
  }

  String? _getSystemAnniversaryLabel(DateTime date) {
    final startedAtRaw = _relationshipStartDate;
    if (startedAtRaw == null || startedAtRaw.isEmpty) return null;

    DateTime startedAt;
    try {
      final parsed = DateTime.parse(startedAtRaw);
      startedAt = DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return null;
    }

    final target = DateTime(date.year, date.month, date.day);
    if (target.isBefore(startedAt)) return null;

    final dayCount = target.difference(startedAt).inDays + 1;
    if (dayCount % 100 == 0 && dayCount <= 10000) {
      return '${dayCount}일';
    }

    final yearDiff = target.year - startedAt.year;
    if (yearDiff > 0 &&
        target.month == startedAt.month &&
        target.day == startedAt.day) {
      return '${yearDiff}주년';
    }

    return null;
  }

  String _selectKoreanParticle({
    required String text,
    required String consonant,
    required String vowel,
  }) {
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) return vowel;

    final lastCodePoint = trimmed.runes.last;
    const hangulStart = 0xAC00;
    const hangulEnd = 0xD7A3;

    if (lastCodePoint < hangulStart || lastCodePoint > hangulEnd) {
      return vowel;
    }

    final jongseongIndex = (lastCodePoint - hangulStart) % 28;
    return jongseongIndex == 0 ? vowel : consonant;
  }

  // ── No Couple State ──────────────────────────────────────────────────────────

  Widget _buildNoCoupleState() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: AppTheme.pageGradient,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.border),
              boxShadow: const [AppTheme.subtleShadow],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.favorite_border_rounded,
                    size: 30,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '아직 연인과 연결되지 않았어요',
                  style: TextStyle(
                    fontSize: 17,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '연결이 완료되면 일정과 기념일을 한 화면에서 함께 볼 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CoupleConnectScreen(),
                        ),
                      );
                      _loadData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.favorite_outline, size: 18),
                    label: const Text(
                      '연인과 연결하기',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Skeleton Loading ─────────────────────────────────────────────────────────

  Widget _buildSkeletonLoading() {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: _DarkSkeletonLoader(),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? label;

  const _TopBarIconButton({
    required this.icon,
    required this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 40,
        padding: EdgeInsets.symmetric(horizontal: label == null ? 11 : 12),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoPreviewResult {
  final bool confirmed;
  final bool reselect;
  final double scale;
  final Offset offset;
  final double viewportWidth;
  final double viewportHeight;
  final bool cropToCard;
  final bool fillToCard;
  final bool useAsMainBackground;

  const _PhotoPreviewResult({
    required this.confirmed,
    this.reselect = false,
    required this.scale,
    required this.offset,
    this.viewportWidth = 1,
    this.viewportHeight = 1,
    this.cropToCard = false,
    this.fillToCard = false,
    this.useAsMainBackground = false,
  });
}

class _DefaultHeroBackdrop extends StatelessWidget {
  const _DefaultHeroBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF74C8FF), Color(0xFFBDE6FF), Color(0xFFF1E6B8)],
              stops: [0.0, 0.56, 1.0],
            ),
          ),
        ),
        CustomPaint(painter: _DefaultHeroBackdropPainter()),
      ],
    );
  }
}

class _DefaultHeroBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final skyCloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.82);
    final hazePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00FFFFFF), Color(0x40FFFFFF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.6));

    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.40, size.width, size.height * 0.20),
      hazePaint,
    );

    for (final rect in <Rect>[
      Rect.fromLTWH(size.width * 0.12, size.height * 0.14, 58, 18),
      Rect.fromLTWH(size.width * 0.30, size.height * 0.08, 46, 14),
      Rect.fromLTWH(size.width * 0.58, size.height * 0.12, 62, 20),
      Rect.fromLTWH(size.width * 0.76, size.height * 0.18, 42, 14),
    ]) {
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));
      canvas.drawRRect(rrect, skyCloudPaint);
      canvas.drawCircle(
        Offset(rect.left + rect.width * 0.22, rect.top + 2),
        rect.height * 0.65,
        skyCloudPaint,
      );
      canvas.drawCircle(
        Offset(rect.left + rect.width * 0.58, rect.top),
        rect.height * 0.75,
        skyCloudPaint,
      );
    }

    final farHill = Path()
      ..moveTo(0, size.height * 0.50)
      ..quadraticBezierTo(
        size.width * 0.20,
        size.height * 0.42,
        size.width * 0.40,
        size.height * 0.48,
      )
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.38,
        size.width,
        size.height * 0.50,
      )
      ..lineTo(size.width, size.height * 0.68)
      ..lineTo(0, size.height * 0.68)
      ..close();
    canvas.drawPath(farHill, Paint()..color = const Color(0xFF7D9F74));

    final valley = Path()
      ..moveTo(0, size.height * 0.60)
      ..quadraticBezierTo(
        size.width * 0.24,
        size.height * 0.52,
        size.width * 0.45,
        size.height * 0.62,
      )
      ..quadraticBezierTo(
        size.width * 0.68,
        size.height * 0.50,
        size.width,
        size.height * 0.60,
      )
      ..lineTo(size.width, size.height * 0.80)
      ..lineTo(0, size.height * 0.80)
      ..close();
    canvas.drawPath(valley, Paint()..color = const Color(0xFFB7C46C));

    final river = Path()
      ..moveTo(size.width * 0.52, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.44,
        size.height * 0.56,
        size.width * 0.38,
        size.height * 0.72,
      )
      ..quadraticBezierTo(
        size.width * 0.34,
        size.height * 0.82,
        size.width * 0.26,
        size.height,
      );
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0xFF7DC7E8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.045
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      river,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.012
        ..strokeCap = StrokeCap.round,
    );

    final nearField = Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.62,
        size.width * 0.50,
        size.height * 0.76,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.66,
        size.width,
        size.height * 0.74,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(nearField, Paint()..color = const Color(0xFF7E973B));

    final wildGrassPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFDFCC79).withValues(alpha: 0.55),
          const Color(0xFF556819),
        ],
      ).createShader(Rect.fromLTWH(0, size.height * 0.70, size.width, size.height));
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.78, size.width, size.height * 0.22),
      wildGrassPaint,
    );

    final blanketRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.46, size.height * 0.86),
        width: size.width * 0.18,
        height: size.height * 0.10,
      ),
      const Radius.circular(18),
    );
    canvas.drawRRect(blanketRect, Paint()..color = const Color(0xC49A7B5F));

    final treePaint = Paint()..color = const Color(0xFF4A4021);
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.08, size.height * 0.52, 8, size.height * 0.18),
      treePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.09, size.height * 0.48),
      size.width * 0.07,
      Paint()..color = const Color(0xFF4D6F2B),
    );

    final villagePaint = Paint()..color = const Color(0xFFEDE4D7);
    for (final house in <Offset>[
      Offset(size.width * 0.72, size.height * 0.56),
      Offset(size.width * 0.77, size.height * 0.58),
      Offset(size.width * 0.82, size.height * 0.55),
      Offset(size.width * 0.87, size.height * 0.57),
    ]) {
      final rect = Rect.fromLTWH(house.dx, house.dy, 18, 12);
      canvas.drawRect(rect, villagePaint);
      final roof = Path()
        ..moveTo(rect.left - 2, rect.top)
        ..lineTo(rect.center.dx, rect.top - 7)
        ..lineTo(rect.right + 2, rect.top)
        ..close();
      canvas.drawPath(roof, Paint()..color = const Color(0xFF815042));
    }

    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.88, size.height * 0.48, 9, size.height * 0.11),
      Paint()..color = const Color(0xFFB9B4A1),
    );
    final steeple = Path()
      ..moveTo(size.width * 0.875, size.height * 0.48)
      ..lineTo(size.width * 0.895, size.height * 0.43)
      ..lineTo(size.width * 0.915, size.height * 0.48)
      ..close();
    canvas.drawPath(steeple, Paint()..color = const Color(0xFF4A4E62));

    final bodyPaint = Paint()..color = const Color(0xFF2D2A27);
    final lightBodyPaint = Paint()..color = const Color(0xFFE7DDCF);
    final center = Offset(size.width * 0.50, size.height * 0.68);

    canvas.drawCircle(Offset(center.dx - 16, center.dy - 42), 10, bodyPaint);
    canvas.drawCircle(Offset(center.dx + 18, center.dy - 40), 10, bodyPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx - 16, center.dy - 8),
          width: 20,
          height: 56,
        ),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFA7A5A0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx + 18, center.dy - 6),
          width: 22,
          height: 54,
        ),
        const Radius.circular(8),
      ),
      lightBodyPaint,
    );

    final limbPaint = Paint()
      ..color = bodyPaint.color
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - 21, center.dy + 18),
      Offset(center.dx - 27, center.dy + 54),
      limbPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 11, center.dy + 18),
      Offset(center.dx - 2, center.dy + 54),
      limbPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 11, center.dy + 20),
      Offset(center.dx + 4, center.dy + 54),
      limbPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 23, center.dy + 18),
      Offset(center.dx + 30, center.dy + 52),
      limbPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 8, center.dy - 12),
      Offset(center.dx + 7, center.dy - 10),
      limbPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DefaultBgOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _DefaultBgOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryLight.withValues(alpha: 0.52)
              : AppTheme.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppTheme.primary : AppTheme.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _CropFramePainter extends CustomPainter {
  final double cardAspectRatio;
  final Color outerColor;

  const _CropFramePainter({
    required this.cardAspectRatio,
    required this.outerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 카드에 맞는 crop 사각형 계산
    late double cropW, cropH;
    if (width / height > cardAspectRatio) {
      // 화면이 카드보다 더 광 → 높이 기준
      cropH = height;
      cropW = height * cardAspectRatio;
    } else {
      // 화면이 더 좁음 → 너비 기준
      cropW = width;
      cropH = width / cardAspectRatio;
    }

    final cropRect = Rect.fromCenter(
      center: Offset(width / 2, height / 2),
      width: cropW,
      height: cropH,
    );

    // 여백 영역 어두움
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, width, height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..color = outerColor,
    );

    // Crop 영역 테두리 (흰색 대시)
    _drawDashedRect(
      canvas,
      cropRect,
      color: Colors.white,
      dashLength: 9,
      gapLength: 6,
      strokeWidth: 2,
    );
  }

  void _drawDashedRect(
    Canvas canvas,
    Rect rect, {
    required Color color,
    required double dashLength,
    required double gapLength,
    required double strokeWidth,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final segmentLength = dashLength + gapLength;

    void drawDashedLine(Offset start, Offset end) {
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final distance = math.sqrt(dx * dx + dy * dy);
      final steps = (distance / segmentLength).ceil();

      for (int i = 0; i < steps; i++) {
        final progress = (i * segmentLength) / distance;
        final nextProgress =
            math.min((i * segmentLength + dashLength) / distance, 1.0);

        canvas.drawLine(
          Offset(start.dx + dx * progress, start.dy + dy * progress),
          Offset(start.dx + dx * nextProgress, start.dy + dy * nextProgress),
          paint,
        );
      }
    }

    const cornerRadius = 16.0;
    final left = rect.left;
    final top = rect.top;
    final right = rect.right;
    final bottom = rect.bottom;

    // Four straight segments
    drawDashedLine(
      Offset(left + cornerRadius, top),
      Offset(right - cornerRadius, top),
    );
    drawDashedLine(
      Offset(right, top + cornerRadius),
      Offset(right, bottom - cornerRadius),
    );
    drawDashedLine(
      Offset(right - cornerRadius, bottom),
      Offset(left + cornerRadius, bottom),
    );
    drawDashedLine(
      Offset(left, bottom - cornerRadius),
      Offset(left, top + cornerRadius),
    );

    final cornerPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Corners as small arcs
    final cornerRect = Rect.fromLTWH(
      left - cornerRadius / 2,
      top - cornerRadius / 2,
      cornerRadius,
      cornerRadius,
    );
    canvas.drawArc(
      cornerRect,
      math.pi,
      math.pi / 2,
      false,
      cornerPaint,
    ); // TL

    canvas.drawArc(
      Rect.fromLTWH(
        right - cornerRadius / 2,
        top - cornerRadius / 2,
        cornerRadius,
        cornerRadius,
      ),
      -math.pi / 2,
      math.pi / 2,
      false,
      cornerPaint,
    ); // TR

    canvas.drawArc(
      Rect.fromLTWH(
        right - cornerRadius / 2,
        bottom - cornerRadius / 2,
        cornerRadius,
        cornerRadius,
      ),
      0,
      math.pi / 2,
      false,
      cornerPaint,
    ); // BR

    canvas.drawArc(
      Rect.fromLTWH(
        left - cornerRadius / 2,
        bottom - cornerRadius / 2,
        cornerRadius,
        cornerRadius,
      ),
      math.pi / 2,
      math.pi / 2,
      false,
      cornerPaint,
    ); // BL
  }

  @override
  bool shouldRepaint(_CropFramePainter oldDelegate) =>
      oldDelegate.cardAspectRatio != cardAspectRatio ||
      oldDelegate.outerColor != outerColor;
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double radius;

  const _DashedRRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = distance + dashLength < metric.length
            ? distance + dashLength
            : metric.length;
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength ||
        oldDelegate.radius != radius;
  }
}

// ─── Dark Skeleton Loader ─────────────────────────────────────────────────────

class _DarkSkeletonLoader extends StatefulWidget {
  const _DarkSkeletonLoader();

  @override
  State<_DarkSkeletonLoader> createState() => _DarkSkeletonLoaderState();
}

class _DarkSkeletonLoaderState extends State<_DarkSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _shimmer({
    required double width,
    required double height,
    double r = 12,
  }) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final c = Color.lerp(
          const Color(0xFFF2EEE8),
          const Color(0xFFE7E0D7),
          _anim.value,
        )!;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(r),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFCF8), Color(0xFFF8F4EE), Color(0xFFF3F6FA)],
          stops: [0.0, 0.42, 1.0],
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: topPad + 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                _shimmer(width: 80, height: 16),
                const Spacer(),
                _shimmer(width: 72, height: 28, r: 20),
              ],
            ),
          ),
          const Spacer(),
          _shimmer(
            width: size.width * 0.68,
            height: size.height * 0.38,
            r: 180,
          ),
          const Spacer(),
          _shimmer(width: 220, height: 42, r: 21),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _shimmer(width: 120, height: 152, r: 16),
                const SizedBox(width: 12),
                _shimmer(width: 120, height: 152, r: 16),
                const SizedBox(width: 12),
                _shimmer(width: 80, height: 152, r: 16),
              ],
            ),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}
