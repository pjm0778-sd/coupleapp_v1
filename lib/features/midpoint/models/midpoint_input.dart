enum TransportMode { publicTransit, car }

enum CarType { normal, electric }

enum DateTheme { date, travel, simple }

extension TransportModeLabel on TransportMode {
  String get label => this == TransportMode.publicTransit ? '대중교통' : '자차';
  String get apiValue => this == TransportMode.publicTransit ? 'publicTransit' : 'car';
}

extension CarTypeLabel on CarType {
  String get label => this == CarType.normal ? '일반차' : '전기차';
  String get apiValue => this == CarType.normal ? 'normal' : 'electric';
}

extension DateThemeLabel on DateTheme {
  String get label {
    switch (this) {
      case DateTheme.date:
        return '데이트';
      case DateTheme.travel:
        return '여행';
      case DateTheme.simple:
        return '중간지점만';
    }
  }

  String get apiValue {
    switch (this) {
      case DateTheme.date:
        return 'date';
      case DateTheme.travel:
        return 'travel';
      case DateTheme.simple:
        return 'simple';
    }
  }

  // 테마별 Kakao 카테고리 코드 목록
  List<String> get kakaoCategories {
    switch (this) {
      case DateTheme.date:
        return ['FD6', 'CE7']; // 음식점, 카페
      case DateTheme.travel:
        return ['AT4', 'AD5']; // 관광명소, 숙박
      case DateTheme.simple:
        return ['FD6'];
    }
  }
}

class MidpointSearchInput {
  final String myOrigin;
  final String partnerOrigin;
  final TransportMode myMode;
  final CarType? myCarType;
  final TransportMode partnerMode;
  final CarType? partnerCarType;
  final DateTheme theme;

  const MidpointSearchInput({
    required this.myOrigin,
    required this.partnerOrigin,
    required this.myMode,
    this.myCarType,
    required this.partnerMode,
    this.partnerCarType,
    required this.theme,
  });

  Map<String, dynamic> toJson() => {
        'myOrigin': myOrigin,
        'partnerOrigin': partnerOrigin,
        'myMode': myMode.apiValue,
        if (myCarType != null) 'myCarType': myCarType!.apiValue,
        'partnerMode': partnerMode.apiValue,
        if (partnerCarType != null) 'partnerCarType': partnerCarType!.apiValue,
        'theme': theme.apiValue,
      };
}
