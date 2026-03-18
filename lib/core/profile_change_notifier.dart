import 'dart:async';

/// 프로필/설정 변경 이벤트 브로드캐스트
/// SettingsScreen 저장 → HomeScreen 자동 갱신에 사용
class ProfileChangeNotifier {
  static final ProfileChangeNotifier _instance =
      ProfileChangeNotifier._internal();
  factory ProfileChangeNotifier() => _instance;
  ProfileChangeNotifier._internal();

  final _controller = StreamController<void>.broadcast();
  Stream<void> get onChange => _controller.stream;
  void notify() => _controller.add(null);
}
