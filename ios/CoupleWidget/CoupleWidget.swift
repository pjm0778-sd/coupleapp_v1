import WidgetKit
import SwiftUI

// MARK: - Data Model

struct CoupleEntry: TimelineEntry {
    let date: Date
    let dDays: Int
    let partnerName: String
    let mySchedule: String
    let partnerSchedule: String
    let myWeather: String
    let partnerWeather: String
    let nextDateDays: Int
    let nextDateLabel: String
}

// MARK: - Timeline Provider

struct CoupleProvider: TimelineProvider {
    private let appGroup = "group.com.coupleapp"

    func placeholder(in context: Context) -> CoupleEntry {
        CoupleEntry(
            date: Date(),
            dDays: 365,
            partnerName: "지수",
            mySchedule: "데이트",
            partnerSchedule: "오전근무",
            myWeather: "서울 🌤 18°",
            partnerWeather: "부산 🌧 14°",
            nextDateDays: 3,
            nextDateLabel: "3월 28일"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CoupleEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CoupleEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> CoupleEntry {
        let defaults = UserDefaults(suiteName: appGroup)
        return CoupleEntry(
            date: Date(),
            dDays: defaults?.integer(forKey: "d_days") ?? 0,
            partnerName: defaults?.string(forKey: "partner_name") ?? "애인",
            mySchedule: defaults?.string(forKey: "my_schedule") ?? "여유로운 하루",
            partnerSchedule: defaults?.string(forKey: "partner_schedule") ?? "여유로운 하루",
            myWeather: defaults?.string(forKey: "my_weather") ?? "",
            partnerWeather: defaults?.string(forKey: "partner_weather") ?? "",
            nextDateDays: defaults?.integer(forKey: "next_date_days") ?? -1,
            nextDateLabel: defaults?.string(forKey: "next_date_label") ?? ""
        )
    }
}

// MARK: - Helpers

extension String {
    var postfix과와: String {
        guard let last = self.last,
              let scalar = last.unicodeScalars.first,
              scalar.value >= 0xAC00, scalar.value <= 0xD7A3 else { return "와" }
        return (scalar.value - 0xAC00) % 28 != 0 ? "과" : "와"
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: CoupleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 2) {
                Text("D+")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "CBA258"))
                Text("\(entry.dDays)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "3D3535"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer()
            }

            Rectangle()
                .fill(Color(hex: "E0D8CC"))
                .frame(height: 1)
                .padding(.vertical, 7)

            HStack(spacing: 4) {
                Text("나")
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: "9E8E8E"))
                    .frame(width: 20, alignment: .leading)
                Text(entry.mySchedule)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "3D3535"))
                    .lineLimit(1)
            }

            HStack(spacing: 4) {
                Text(String(entry.partnerName.prefix(2)))
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: "9E8E8E"))
                    .frame(width: 20, alignment: .leading)
                Text(entry.partnerSchedule)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "3D3535"))
                    .lineLimit(1)
            }
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(14)
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: CoupleEntry

    private var headerText: String {
        "\(entry.partnerName)\(entry.partnerName.postfix과와) 함께한지 D+\(entry.dDays)"
    }

    private var hasNextDate: Bool {
        entry.nextDateDays >= 0 && !entry.nextDateLabel.isEmpty
    }

    private var nextDateText: String {
        entry.nextDateDays == 0 ? "오늘!" : "D-\(entry.nextDateDays)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(headerText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "3D3535"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
            }

            Rectangle()
                .fill(Color(hex: "E0D8CC"))
                .frame(height: 1)
                .padding(.vertical, 7)

            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Text("나")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "9E8E8E"))
                            .frame(width: 22, alignment: .leading)
                        Text(entry.mySchedule)
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "3D3535"))
                            .lineLimit(1)
                    }
                    HStack(spacing: 4) {
                        Text(String(entry.partnerName.prefix(2)))
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "9E8E8E"))
                            .frame(width: 22, alignment: .leading)
                        Text(entry.partnerSchedule)
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "3D3535"))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(Color(hex: "E0D8CC"))
                    .frame(width: 1)
                    .padding(.horizontal, 8)

                VStack(alignment: .leading, spacing: 5) {
                    if !entry.myWeather.isEmpty {
                        Text(entry.myWeather)
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "3D3535"))
                            .lineLimit(1)
                    }
                    if !entry.partnerWeather.isEmpty {
                        Text(entry.partnerWeather)
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "3D3535"))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if hasNextDate {
                Rectangle()
                    .fill(Color(hex: "E0D8CC"))
                    .frame(height: 1)
                    .padding(.vertical, 5)

                HStack {
                    Text("💕 설레는 다음 만남까지")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "5A5050"))
                    Spacer()
                    Text(nextDateText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "CBA258"))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
    }
}

// MARK: - Entry View

struct CoupleWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: CoupleEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget

struct CoupleWidget: Widget {
    let kind: String = "CoupleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoupleProvider()) { entry in
            CoupleWidgetEntryView(entry: entry)
                .containerBackground(Color(hex: "FAF7F2"), for: .widget)
        }
        .configurationDisplayName("커플듀티")
        .description("오늘 일정과 D+를 확인하세요")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
