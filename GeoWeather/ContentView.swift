import SwiftUI

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}

struct ContentView: View {
    @EnvironmentObject var store: WeatherStore
    @EnvironmentObject var locationManager: LocationManager
    @State private var showCities = false
    @State private var didLocate = false

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $store.selectedID) {
                ForEach(store.cities) { city in
                    WeatherPageView(city: city)
                        .tag(city.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            HStack {
                Button {
                    locationManager.requestLocation()
                } label: {
                    Image(systemName: "location.fill")
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                Spacer()
                Button {
                    showCities = true
                } label: {
                    Image(systemName: "list.bullet")
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showCities) {
            CitySearchView()
        }
        .onAppear {
            locationManager.requestLocation()
        }
        .onChange(of: locationManager.locatedCity) { _, newCity in
            guard let newCity, !didLocate else { return }
            didLocate = true
            store.setLocatedCity(newCity)
        }
    }
}

struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct WeatherPageView: View {
    let city: City
    @State private var forecast: ForecastResponse?
    @State private var air: AirQualityResponse?
    @State private var errorText: String?

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    header
                    if let f = forecast {
                        currentCard(f.current)
                        hourlyCard(f)
                        dailyCard(f)
                        detailsGrid(f)
                    } else if let errorText {
                        Text(errorText)
                            .foregroundStyle(.white)
                            .padding(.top, 80)
                    } else {
                        ProgressView()
                            .tint(.white)
                            .padding(.top, 80)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .padding(.bottom, 30)
            }
            .refreshable { await load() }
        }
        .task(id: city.id) { await load() }
    }

    private var backgroundGradient: LinearGradient {
        let pair: (top: String, bottom: String)
        if let c = forecast?.current {
            pair = WeatherCode.gradient(c.weather_code, isDay: c.is_day == 1)
        } else {
            pair = ("#3D7BDB", "#7FB2F0")
        }
        return LinearGradient(colors: [Color(hex: pair.top), Color(hex: pair.bottom)],
                              startPoint: .top, endPoint: .bottom)
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text(city.name)
                .font(.title.weight(.semibold))
            if !city.subtitle.isEmpty {
                Text(city.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            if let t = forecast?.current.time {
                Text("更新于 \(String(t.dropFirst(11).prefix(5)))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func currentCard(_ c: CurrentWeather) -> some View {
        Card(title: "当前天气") {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: WeatherCode.symbol(c.weather_code, isDay: c.is_day == 1))
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 60))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(c.temperature_2m.rounded()))°")
                        .font(.system(size: 64, weight: .thin))
                    Text(WeatherCode.text(c.weather_code))
                        .font(.headline)
                    Text("体感 \(Int(c.apparent_temperature.rounded()))°")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }
            Divider().overlay(.white.opacity(0.3))
            HStack {
                statItem("湿度", "\(c.relative_humidity_2m)%")
                statItem("风速", "\(Int(c.wind_speed_10m.rounded())) km/h")
                statItem("阵风", "\(Int(c.wind_gusts_10m.rounded())) km/h")
                statItem("气压", "\(Int(c.surface_pressure_msl.rounded())) hPa")
            }
        }
    }

    private func statItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.weight(.semibold))
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
    }

    private func hourlyCard(_ f: ForecastResponse) -> some View {
        Card(title: "逐小时预报") {
            let items = next24Hours(f)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                        VStack(spacing: 6) {
                            Text(idx == 0 ? "现在" : item.hour)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.85))
                            Image(systemName: WeatherCode.symbol(item.code, isDay: true))
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 20))
                            Text("\(Int(item.temp.rounded()))°")
                                .font(.subheadline.weight(.semibold))
                            Text(item.precip.map { "\($0)%" } ?? " ")
                                .font(.caption2)
                                .foregroundStyle(Color(hex: "#BFE0FF"))
                        }
                    }
                }
            }
        }
    }

    private struct HourItem {
        let hour: String
        let code: Int
        let temp: Double
        let precip: Int?
    }

    private func next24Hours(_ f: ForecastResponse) -> [HourItem] {
        let hourKey = String(f.current.time.prefix(13))
        let start = f.hourly.time.firstIndex { $0.hasPrefix(hourKey) } ?? 0
        let end = min(start + 24, f.hourly.time.count)
        guard start < end else { return [] }
        return (start..<end).map { i in
            HourItem(hour: String(f.hourly.time[i].dropFirst(11).prefix(5)),
                     code: f.hourly.weather_code[i],
                     temp: f.hourly.temperature_2m[i],
                     precip: f.hourly.precipitation_probability?[i] ?? nil)
        }
    }

    private func dailyCard(_ f: ForecastResponse) -> some View {
        Card(title: "15 日预报") {
            let d = f.daily
            let weekMin = d.temperature_2m_min.min() ?? 0
            let weekMax = d.temperature_2m_max.max() ?? 1
            VStack(spacing: 10) {
                ForEach(Array(d.time.enumerated()), id: \.offset) { i, dateStr in
                    HStack(spacing: 8) {
                        Text(weekdayText(dateStr, timezone: f.timezone, index: i))
                            .font(.subheadline)
                            .frame(width: 44, alignment: .leading)
                        Image(systemName: WeatherCode.symbol(d.weather_code[i], isDay: true))
                            .symbolRenderingMode(.multicolor)
                            .frame(width: 24)
                        Text(d.precipitation_probability_max?[i].map { "\($0)%" } ?? "")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: "#BFE0FF"))
                            .frame(width: 34, alignment: .leading)
                        Text("\(Int(d.temperature_2m_min[i].rounded()))°")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 34, alignment: .trailing)
                        rangeBar(min: d.temperature_2m_min[i], max: d.temperature_2m_max[i],
                                 weekMin: weekMin, weekMax: weekMax)
                            .frame(height: 5)
                        Text("\(Int(d.temperature_2m_max[i].rounded()))°")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 34, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func rangeBar(min lo: Double, max hi: Double, weekMin: Double, weekMax: Double) -> some View {
        GeometryReader { geo in
            let span = max(weekMax - weekMin, 0.1)
            let x0 = CGFloat((lo - weekMin) / span) * geo.size.width
            let w = max(CGFloat((hi - lo) / span) * geo.size.width, 6)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25))
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "#7FD4FF"), Color(hex: "#FFD37F")],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: w)
                    .offset(x: x0)
            }
        }
    }

    private func detailsGrid(_ f: ForecastResponse) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            Card(title: "空气质量") {
                if let aqi = air?.current.us_aqi {
                    Text("\(Int(aqi.rounded())) · \(aqiCategory(aqi))")
                        .font(.headline)
                    Text("PM2.5 \(fmt(air?.current.pm2_5)) · PM10 \(fmt(air?.current.pm10))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    Text("暂无数据").font(.subheadline)
                }
            }
            Card(title: "日出日落") {
                Text("日出 \(hhmm(f.daily.sunrise.first))")
                    .font(.headline)
                Text("日落 \(hhmm(f.daily.sunset.first))")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Card(title: "紫外线") {
                let uv = f.daily.uv_index_max.first ?? 0
                Text("\(Int(uv.rounded())) · \(uvLevel(uv))")
                    .font(.headline)
                Text("今日最大值")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Card(title: "风况") {
                let c = f.current
                Text("\(compass(c.wind_direction_10m))风 \(Int(c.wind_speed_10m.rounded())) km/h")
                    .font(.headline)
                Text("风向 \(c.wind_direction_10m)°")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    // MARK: - Helpers

    private func load() async {
        do {
            forecast = try await WeatherService.fetchForecast(for: city)
            errorText = nil
        } catch {
            if forecast == nil { errorText = "加载失败，请下拉重试" }
        }
        air = try? await WeatherService.fetchAirQuality(for: city)
    }

    private func hhmm(_ iso: String?) -> String {
        guard let iso else { return "--:--" }
        return String(iso.dropFirst(11).prefix(5))
    }

    private func fmt(_ v: Double?) -> String {
        guard let v else { return "--" }
        return "\(Int(v.rounded()))"
    }

    private func compass(_ deg: Int) -> String {
        let dirs = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
        return dirs[((deg + 22) / 45) % 8]
    }

    private func aqiCategory(_ aqi: Double) -> String {
        switch aqi {
        case ..<51: return "优"
        case ..<101: return "良"
        case ..<151: return "轻度污染"
        case ..<201: return "中度污染"
        case ..<301: return "重度污染"
        default: return "严重污染"
        }
    }

    private func uvLevel(_ uv: Double) -> String {
        switch uv {
        case ..<3: return "弱"
        case ..<6: return "中等"
        case ..<8: return "强"
        case ..<11: return "很强"
        default: return "极强"
        }
    }

    private func weekdayText(_ dateStr: String, timezone: String, index: Int) -> String {
        if index == 0 { return "今天" }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: timezone) ?? .current
        guard let date = parser.date(from: dateStr) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "EEE"
        f.timeZone = TimeZone(identifier: timezone) ?? .current
        return f.string(from: date)
    }
}
