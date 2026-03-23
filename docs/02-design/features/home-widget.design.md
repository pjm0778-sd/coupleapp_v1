# Design: home-widget

## 1. 아키텍처 개요

```
Flutter App (로그인 후 데이터 로드 시점)
        │
        ▼
HomeWidgetService.updateWidget(data)
        │
        ├── home_widget 패키지 (SharedPreferences / App Groups)
        │
        ├── Android: CoupleWidgetProvider.onUpdate() → RemoteViews XML
        └── iOS: WidgetKit TimelineProvider → SwiftUI View
```

---

## 2. Flutter 측 설계

### 2-1. HomeWidgetService (전면 재작성)

**파일**: `lib/core/home_widget_service.dart`

```
class HomeWidgetService
  - static const appGroupId  = 'group.com.coupleapp'
  - static const iOSName     = 'CoupleWidget'
  - static const androidName = 'CoupleWidgetProvider'

  + static Future<void> init()
      └── HomeWidget.setAppGroupId(appGroupId)   // iOS only, 무시 가능

  + static Future<void> updateWidget(WidgetData data)
      ├── HomeWidget.saveWidgetData('d_days',           data.dDays)
      ├── HomeWidget.saveWidgetData('partner_name',     data.partnerName)
      ├── HomeWidget.saveWidgetData('my_schedule',      data.mySchedule)
      ├── HomeWidget.saveWidgetData('partner_schedule', data.partnerSchedule)
      ├── HomeWidget.saveWidgetData('my_weather',       data.myWeather)      // "서울 🌤 18°"
      ├── HomeWidget.saveWidgetData('partner_weather',  data.partnerWeather) // "부산 🌧 12°"
      ├── HomeWidget.saveWidgetData('next_date_days',   data.nextDateDays)   // -1 이면 없음
      ├── HomeWidget.saveWidgetData('next_date_label',  data.nextDateLabel)  // "3월 28일"
      └── HomeWidget.updateWidget(iOSName: iOSName, androidName: androidName)
```

### 2-2. WidgetData 모델

**파일**: `lib/core/home_widget_service.dart` 내부 클래스

```dart
class WidgetData {
  final int    dDays;
  final String partnerName;
  final String mySchedule;        // 없으면 "여유로운 하루"
  final String partnerSchedule;   // 없으면 "여유로운 하루"
  final String myWeather;         // "서울 🌤 18°" 또는 ""
  final String partnerWeather;    // "부산 🌧 12°" 또는 ""
  final int    nextDateDays;      // -1 = 없음, 0 = 오늘
  final String nextDateLabel;     // "3월 28일" 또는 ""
}
```

### 2-3. HomeScreen 연동 위치

**파일**: `lib/features/home/screens/home_screen.dart`

`_loadData()` 완료 후 → `_updateHomeWidget()` 호출

```dart
Future<void> _updateHomeWidget() async {
  // _data, _profile 에서 필요 데이터 추출
  // WeatherService로 날씨 조회 (캐시 있으면 즉시)
  // HomeWidgetService.updateWidget(data) 호출
}
```

날씨 조회:
- `_profile?.myCity` → WeatherService → `"도시 이모지 온도°"`
- `_profile?.partnerCity` → WeatherService → 동일

날씨 이모지 변환 (WeatherData.weatherCode 기준):
| WMO code 범위 | 이모지 |
|--------------|--------|
| 0 | ☀️ |
| 1–3 | 🌤 |
| 45, 48 | 🌫 |
| 51–67 | 🌧 |
| 71–77 | ❄️ |
| 80–82 | 🌦 |
| 95–99 | ⛈ |

### 2-4. main.dart 초기화

앱 시작 시 `HomeWidgetService.init()` 호출 (App Group 초기화)

---

## 3. Android 네이티브 설계

### 파일 구조

```
android/app/src/main/
├── kotlin/com/coupleduty/app/
│   └── CoupleWidgetProvider.kt          ← AppWidgetProvider
├── res/
│   ├── layout/
│   │   ├── widget_small.xml             ← Small 2×2 레이아웃
│   │   └── widget_medium.xml            ← Medium 4×2 레이아웃
│   └── xml/
│       ├── widget_info_small.xml        ← 위젯 메타데이터
│       └── widget_info_medium.xml
└── AndroidManifest.xml                  ← receiver 2개 추가
```

### CoupleWidgetProvider.kt 설계

```kotlin
class CoupleWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context, appWidgetManager, appWidgetIds) {
        for (id in appWidgetIds) {
            val widgetInfo = appWidgetManager.getAppWidgetInfo(id)
            val isSmall = widgetInfo.minWidth <= 180  // dp 기준
            updateWidget(context, appWidgetManager, id, isSmall)
        }
    }

    private fun updateWidget(context, manager, id, isSmall) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", 0)
        // 데이터 읽기 (home_widget 패키지 키 형식: "flutter.{key}")
        val dDays           = prefs.getLong("flutter.d_days", 0)
        val partnerName     = prefs.getString("flutter.partner_name", "애인") ?: "애인"
        val mySchedule      = prefs.getString("flutter.my_schedule", "여유로운 하루") ?: ""
        val partnerSchedule = prefs.getString("flutter.partner_schedule", "여유로운 하루") ?: ""
        val myWeather       = prefs.getString("flutter.my_weather", "") ?: ""
        val partnerWeather  = prefs.getString("flutter.partner_weather", "") ?: ""
        val nextDateDays    = prefs.getLong("flutter.next_date_days", -1)
        val nextDateLabel   = prefs.getString("flutter.next_date_label", "") ?: ""

        val layout = if (isSmall) R.layout.widget_small else R.layout.widget_medium
        val views  = RemoteViews(context.packageName, layout)

        // 공통
        views.setTextViewText(R.id.tv_d_days,      "D+$dDays")
        views.setTextViewText(R.id.tv_partner_name, partnerName)
        views.setTextViewText(R.id.tv_my_schedule,  mySchedule)
        views.setTextViewText(R.id.tv_partner_schedule, partnerSchedule)

        // Medium 전용
        if (!isSmall) {
            views.setTextViewText(R.id.tv_my_weather,      myWeather)
            views.setTextViewText(R.id.tv_partner_weather, partnerWeather)
            if (nextDateDays >= 0) {
                val dText = if (nextDateDays == 0L) "오늘!" else "D-$nextDateDays"
                views.setTextViewText(R.id.tv_next_date, "$nextDateLabel  $dText")
                views.setViewVisibility(R.id.layout_next_date, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.layout_next_date, View.GONE)
            }
        }

        // 탭 시 앱 열기
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pending = PendingIntent.getActivity(context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.widget_root, pending)

        manager.updateAppWidget(id, views)
    }
}
```

### widget_info_small.xml

```xml
<appwidget-provider
    android:minWidth="110dp"
    android:minHeight="110dp"
    android:targetCellWidth="2"
    android:targetCellHeight="2"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/widget_small"
    android:widgetCategory="home_screen"
    android:description="@string/widget_description_small" />
```

### widget_info_medium.xml

```xml
<appwidget-provider
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:targetCellWidth="4"
    android:targetCellHeight="2"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/widget_medium"
    android:widgetCategory="home_screen"
    android:description="@string/widget_description_medium" />
```

### widget_small.xml 레이아웃 구조

```
LinearLayout (vertical, id=widget_root, background=@drawable/widget_bg)
  ├── TextView  tv_d_days          "D+365"   (bold, large)
  ├── TextView  tv_partner_name    "파트너와 함께"  (small, gray)
  ├── View      divider
  ├── LinearLayout (horizontal)
  │   ├── TextView  tv_my_schedule_label  "나"
  │   └── TextView  tv_my_schedule        "회의 10:00"
  └── LinearLayout (horizontal)
      ├── TextView  tv_partner_label       "파트너"
      └── TextView  tv_partner_schedule    "여유로운 하루"
```

### widget_medium.xml 레이아웃 구조

```
LinearLayout (vertical, id=widget_root, background=@drawable/widget_bg)
  ├── LinearLayout (horizontal)    // 헤더
  │   ├── TextView  tv_d_days       "D+365"   (bold, large)
  │   └── TextView  tv_partner_name "파트너와 함께"
  ├── View  divider
  ├── LinearLayout (horizontal)    // 일정 + 날씨
  │   ├── LinearLayout (vertical, weight=1)  // 일정
  │   │   ├── LinearLayout tv_my_schedule_label + tv_my_schedule
  │   │   └── LinearLayout tv_partner_label  + tv_partner_schedule
  │   └── LinearLayout (vertical, weight=1)  // 날씨
  │       ├── TextView  tv_my_weather         "서울 🌤 18°"
  │       └── TextView  tv_partner_weather    "부산 🌧 12°"
  └── LinearLayout (id=layout_next_date, horizontal)  // 다음 데이트
      ├── TextView  "📅"
      └── TextView  tv_next_date   "3월 28일  D-5"
```

### AndroidManifest.xml 추가 내용

```xml
<!-- Small 위젯 -->
<receiver
    android:name=".CoupleWidgetProvider"
    android:exported="true"
    android:label="커플듀티 위젯 (Small)">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/widget_info_small"/>
</receiver>

<!-- Medium 위젯 (별도 클래스 없이 동일 Provider, info XML만 다름) -->
<receiver
    android:name=".CoupleWidgetProviderMedium"
    android:exported="true"
    android:label="커플듀티 위젯 (Medium)">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/widget_info_medium"/>
</receiver>
```

> **참고**: Small/Medium을 한 클래스(`CoupleWidgetProvider`)에서 처리하되, Android는 위젯 크기를 receiver별 info XML로 등록하는 방식이므로 `CoupleWidgetProviderMedium`은 `CoupleWidgetProvider`를 상속만 함.

---

## 4. iOS 네이티브 설계

> **중요**: iOS 위젯은 Xcode에서 Widget Extension Target을 직접 추가해야 함.
> Xcode 없이는 불가. 아래는 추가 후 작성할 Swift 코드 설계.

### 파일 구조 (Xcode에서 생성)

```
ios/
├── Runner/
│   └── AppDelegate.swift        ← App Group 설정 추가
└── CoupleWidget/                ← Xcode Target 추가 후 생성
    ├── CoupleWidget.swift        ← 메인 Widget 코드
    ├── CoupleWidgetEntry.swift   ← TimelineEntry 모델
    ├── CoupleWidgetProvider.swift← TimelineProvider
    └── Info.plist                ← Bundle ID, App Group 설정
```

### CoupleWidgetEntry.swift

```swift
struct CoupleWidgetEntry: TimelineEntry {
    let date: Date
    let dDays: Int
    let partnerName: String
    let mySchedule: String
    let partnerSchedule: String
    let myWeather: String        // Medium only
    let partnerWeather: String   // Medium only
    let nextDateDays: Int        // -1 = 없음
    let nextDateLabel: String    // Medium only

    static var placeholder: CoupleWidgetEntry {
        CoupleWidgetEntry(date: Date(), dDays: 365,
            partnerName: "애인", mySchedule: "회의",
            partnerSchedule: "여유로운 하루",
            myWeather: "서울 🌤 18°", partnerWeather: "부산 🌧 12°",
            nextDateDays: 5, nextDateLabel: "3월 28일")
    }
}
```

### CoupleWidgetProvider.swift (TimelineProvider)

```swift
struct CoupleWidgetProvider: TimelineProvider {
    let userDefaults = UserDefaults(suiteName: "group.com.coupleapp")!

    func placeholder(in context: Context) -> CoupleWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (CoupleWidgetEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CoupleWidgetEntry>) -> Void) {
        let entry = readEntry()
        // 30분마다 갱신
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func readEntry() -> CoupleWidgetEntry {
        CoupleWidgetEntry(
            date: Date(),
            dDays:           userDefaults.integer(forKey: "flutter.d_days"),
            partnerName:     userDefaults.string(forKey: "flutter.partner_name")     ?? "애인",
            mySchedule:      userDefaults.string(forKey: "flutter.my_schedule")      ?? "여유로운 하루",
            partnerSchedule: userDefaults.string(forKey: "flutter.partner_schedule") ?? "여유로운 하루",
            myWeather:       userDefaults.string(forKey: "flutter.my_weather")       ?? "",
            partnerWeather:  userDefaults.string(forKey: "flutter.partner_weather")  ?? "",
            nextDateDays:    userDefaults.integer(forKey: "flutter.next_date_days"),
            nextDateLabel:   userDefaults.string(forKey: "flutter.next_date_label")  ?? ""
        )
    }
}
```

### CoupleWidget.swift (SwiftUI View)

```swift
@main
struct CoupleWidgetBundle: WidgetBundle {
    var body: some Widget {
        CoupleWidgetSmall()
        CoupleWidgetMedium()
    }
}

struct CoupleWidgetSmall: Widget {
    let kind = "CoupleWidgetSmall"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoupleWidgetProvider()) { entry in
            SmallWidgetView(entry: entry)
        }
        .configurationDisplayName("커플듀티 (Small)")
        .description("D+일수와 오늘 일정을 표시합니다.")
        .supportedFamilies([.systemSmall])
    }
}

struct CoupleWidgetMedium: Widget {
    let kind = "CoupleWidgetMedium"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoupleWidgetProvider()) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("커플듀티 (Medium)")
        .description("일정, 날씨, 다음 데이트를 표시합니다.")
        .supportedFamilies([.systemMedium])
    }
}

// Small View
struct SmallWidgetView: View {
    let entry: CoupleWidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // D+N 헤더
            HStack {
                Text("💑").font(.system(size: 14))
                Text("D+\(entry.dDays)").font(.system(size: 28, weight: .bold))
            }
            Text("\(entry.partnerName)와 함께").font(.system(size: 10)).foregroundColor(.secondary)
            Divider()
            // 일정
            HStack { Text("나").font(.caption2).foregroundColor(.secondary); Spacer()
                     Text(entry.mySchedule).font(.caption).lineLimit(1) }
            HStack { Text("파트너").font(.caption2).foregroundColor(.secondary); Spacer()
                     Text(entry.partnerSchedule).font(.caption).lineLimit(1) }
        }
        .padding(12)
        .background(Color(.systemBackground))
    }
}

// Medium View
struct MediumWidgetView: View {
    let entry: CoupleWidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 헤더
            HStack {
                Text("💑").font(.system(size: 14))
                Text("D+\(entry.dDays)").font(.system(size: 26, weight: .bold))
                Spacer()
                Text("\(entry.partnerName)와 함께").font(.caption).foregroundColor(.secondary)
            }
            Divider()
            // 일정 + 날씨 (좌우 분할)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    scheduleRow(label: "나", text: entry.mySchedule)
                    scheduleRow(label: "파트너", text: entry.partnerSchedule)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    if !entry.myWeather.isEmpty      { Text(entry.myWeather).font(.caption) }
                    if !entry.partnerWeather.isEmpty { Text(entry.partnerWeather).font(.caption) }
                }
            }
            // 다음 데이트
            if entry.nextDateDays >= 0 {
                Divider()
                HStack {
                    Text("📅").font(.caption)
                    Text(entry.nextDateLabel).font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(entry.nextDateDays == 0 ? "오늘!" : "D-\(entry.nextDateDays)")
                        .font(.caption).fontWeight(.semibold).foregroundColor(.orange)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func scheduleRow(label: String, text: String) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2).foregroundColor(.secondary).frame(width: 30, alignment: .leading)
            Text(text).font(.caption).lineLimit(1)
        }
    }
}
```

### AppDelegate.swift 추가

```swift
// didFinishLaunchingWithOptions 내부에 추가
HomeWidget.setAppGroupId("group.com.coupleapp")  // home_widget 패키지 제공
```

---

## 5. 구현 순서 (Do Phase)

| 순서 | 영역 | 작업 | 파일 |
|------|------|------|------|
| 1 | Flutter | HomeWidgetService 재작성 | `lib/core/home_widget_service.dart` |
| 2 | Flutter | HomeScreen에 `_updateHomeWidget()` 추가 | `home_screen.dart` |
| 3 | Flutter | main.dart 초기화 | `lib/main.dart` |
| 4 | Android | CoupleWidgetProvider.kt 생성 | `kotlin/.../CoupleWidgetProvider.kt` |
| 5 | Android | CoupleWidgetProviderMedium.kt 생성 | 동일 경로 |
| 6 | Android | XML 레이아웃 4개 생성 | `res/layout/`, `res/xml/` |
| 7 | Android | AndroidManifest.xml 수정 | `AndroidManifest.xml` |
| 8 | iOS | AppDelegate.swift 수정 | `ios/Runner/AppDelegate.swift` |
| 9 | iOS | Widget Extension Swift 코드 (Xcode 설정 안내 포함) | `ios/CoupleWidget/` |

---

## 6. 데이터 키 매핑 (home_widget 패키지 규칙)

Android SharedPreferences에서 읽을 때 키는 `"flutter.{key}"` 형식:

| Flutter saveWidgetData key | Android 읽기 키 | iOS 읽기 키 |
|----------------------------|-----------------|-------------|
| `d_days` | `flutter.d_days` (Long) | `flutter.d_days` (Int) |
| `partner_name` | `flutter.partner_name` (String) | `flutter.partner_name` |
| `my_schedule` | `flutter.my_schedule` (String) | `flutter.my_schedule` |
| `partner_schedule` | `flutter.partner_schedule` | `flutter.partner_schedule` |
| `my_weather` | `flutter.my_weather` | `flutter.my_weather` |
| `partner_weather` | `flutter.partner_weather` | `flutter.partner_weather` |
| `next_date_days` | `flutter.next_date_days` (Long) | `flutter.next_date_days` |
| `next_date_label` | `flutter.next_date_label` | `flutter.next_date_label` |
