// GeoWeatherWidget.swift — 几何天气小组件（小号 + 中号）
// 数据来自主 App 写入 App Group 的快照；取时间线时顺带按快照坐标自刷新一次。
import WidgetKit
import SwiftUI

@main
struct GeoWeatherWidgetBundle: WidgetBundle {
    var body: some Widget {
        GeoWeatherWidget()
    }
}

struct GeoWeatherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GeoWeatherWidget", provider: Provider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("几何天气")
        .description("当前天气、体感与今日高低温")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let snapshot: SharedSnapshot?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: Date(), snapshot: SharedSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            var snap = SharedSnapshotStore.load()
            if let s = snap {
                let city = City(name: s.cityName, country: nil, admin1: nil,
                                latitude: s.latitude, longitude: s.longitude)
                if let f = try? await WeatherService.fetchForecast(for: city) {
                    let fresh = SharedSnapshot.make(from: f, city: city)
                    SharedSnapshotStore.save(fresh)
                    snap = fresh
                }
            }
            let entry = Entry(date: Date(), snapshot: snap)
            let next = Date().addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

private extension Color {
    init(hexString: String) {
        let s = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}

struct WidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry

    var body: some View {
        Group {
            if let s = entry.snapshot {
                if family == .systemMedium {
                    mediumContent(s)
                } else {
                    smallContent(s)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.title2)
                    Text("打开几何天气刷新一次")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
            }
        }
        .containerBackground(for: .widget) {
            gradient
        }
    }

    private var gradient: LinearGradient {
        let pair = entry.snapshot.map { WeatherCode.gradient($0.code, isDay: $0.isDay) }
            ?? (top: "#3D7BDB", bottom: "#7FB2F0")
        return LinearGradient(colors: [Color(hexString: pair.top), Color(hexString: pair.bottom)],
                              startPoint: .top, endPoint: .bottom)
    }

    private func icon(_ s: SharedSnapshot, size: CGFloat) -> some View {
        Group {
            if let ui = WeatherIconData.image(named: WeatherCode.iconName(s.code, isDay: s.isDay)) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "cloud.fill")
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
    }

    private func smallContent(_ s: SharedSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(s.cityName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                icon(s, size: 30)
            }
            Text("\(Int(s.temperature.rounded()))°")
                .font(.system(size: 40, weight: .thin))
            Text(WeatherCode.text(s.code))
                .font(.subheadline)
            Text("最高 \(Int(s.high.rounded()))° · 最低 \(Int(s.low.rounded()))°")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func mediumContent(_ s: SharedSnapshot) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(s.cityName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(alignment: .center, spacing: 8) {
                    icon(s, size: 44)
                    Text("\(Int(s.temperature.rounded()))°")
                        .font(.system(size: 44, weight: .thin))
                }
                Text(WeatherCode.text(s.code))
                    .font(.subheadline)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("最高 \(Int(s.high.rounded()))°")
                Text("最低 \(Int(s.low.rounded()))°")
                Text("体感 \(Int(s.feelsLike.rounded()))°")
                Text("湿度 \(s.humidity)%")
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.95))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
