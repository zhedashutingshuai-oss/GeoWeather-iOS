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
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                Spacer()
                Button {
                    showCities = true
                } label: {
                    Image(systemName: "list.bullet")
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
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
        .glassEffect(.regular.tint(.white.opacity(0.10)),
                     in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// 原版几何天气图标：静态图，或帧动画（大图标用）
struct WeatherIcon: View {
    let code: Int
    let isDay: Bool
    var size: CGFloat = 24
    var animated: Bool = false

    private func iconImage(_ name: String) -> some View {
        Group {
            if let ui = WeatherIconData.image(named: name) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "cloud.fill")
                    .resizable()
                    .scaledToFit()
            }
        }
    }

    var body: some View {
        if animated {
            TimelineView(.periodic(from: .now, by: 0.45)) { ctx in
                let frames = WeatherCode.iconFrames(code, isDay: isDay)
                let idx = Int(ctx.date.timeIntervalSinceReferenceDate / 0.45) % frames.count
                iconImage(frames[idx])
            }
            .frame(width: size, height: size)
        } else {
            iconImage(WeatherCode.iconName(code, isDay: isDay))
                .frame(width: size, height: size)
        }
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
                GlassEffectContainer(spacing: 14) {
                VStack(spacing: 14) {
                    header
                    if let f = forecast {
                        currentCard(f)
                        dailyCard(f)
                        hourlyCard(f)
                        sunCard(f)
                        detailsGrid(f)
                        lifeCard(f)
                        footer(f)
                    } else if let errorText {
                        Text(errorText)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, 80)
                            .padding(.horizontal, 8)
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

    // MARK: - 当前天气

    private func currentCard(_ f: ForecastResponse) -> some View {
        let c = f.current
        return Card(title: "当前天气") {
            HStack(alignment: .center, spacing: 16) {
                WeatherIcon(code: c.weather_code, isDay: c.is_day == 1, size: 76, animated: true)
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
                if let hi = f.daily.temperature_2m_max.first, let lo = f.daily.temperature_2m_min.first {
                    VStack(alignment: .trailing, spacing: 4) {
                        Label("\(Int(hi.rounded()))°", systemImage: "arrow.up")
                        Label("\(Int(lo.rounded()))°", systemImage: "arrow.down")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                }
            }
            Divider().overlay(.white.opacity(0.3))
            HStack {
                statItem("湿度", "\(c.relative_humidity_2m)%")
                statItem("风速", "\(Int(c.wind_speed_10m.rounded())) km/h")
                statItem("阵风", "\(Int(c.wind_gusts_10m.rounded())) km/h")
                statItem("气压", "\(Int(c.pressure_msl.rounded())) hPa")
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

    // MARK: - 逐小时（带温度曲线）

    private struct HourItem {
        let hour: String
        let code: Int
        let temp: Double
        let precip: Int?
    }

    private func currentHourIndex(_ f: ForecastResponse) -> Int {
        let hourKey = String(f.current.time.prefix(13))
        return f.hourly.time.firstIndex { $0.hasPrefix(hourKey) } ?? 0
    }

    private func next24Hours(_ f: ForecastResponse) -> [HourItem] {
        let start = currentHourIndex(f)
        let end = min(start + 24, f.hourly.time.count)
        guard start < end else { return [] }
        return (start..<end).map { i in
            HourItem(hour: String(f.hourly.time[i].dropFirst(11).prefix(5)),
                     code: f.hourly.weather_code[i],
                     temp: f.hourly.temperature_2m[i],
                     precip: f.hourly.precipitation_probability?[i] ?? nil)
        }
    }

    private func hourlyCard(_ f: ForecastResponse) -> some View {
        let items = next24Hours(f)
        let colW: CGFloat = 54
        return Card(title: "逐小时预报") {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 2) {
                    HStack(spacing: 0) {
                        ForEach(items.indices, id: \.self) { idx in
                            let item = items[idx]
                            VStack(spacing: 6) {
                                Text(idx == 0 ? "现在" : item.hour)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                                WeatherIcon(code: item.code, isDay: true, size: 26)
                                Text("\(Int(item.temp.rounded()))°")
                                    .font(.subheadline.weight(.semibold))
                                Text(item.precip.map { "\($0)%" } ?? " ")
                                    .font(.caption2)
                                    .foregroundStyle(Color(hex: "#BFE0FF"))
                            }
                            .frame(width: colW)
                        }
                    }
                    tempCurve(items: items, colW: colW)
                        .frame(width: colW * CGFloat(items.count), height: 46)
                }
            }
        }
    }

    /// 温度曲线：平滑折线 + 数据点
    private func tempCurve(items: [HourItem], colW: CGFloat) -> some View {
        let temps = items.map(\.temp)
        let lo = (temps.min() ?? 0) - 1
        let hi = (temps.max() ?? 1) + 1
        let h: CGFloat = 46
        let points: [CGPoint] = items.enumerated().map { i, item in
            let x = colW * CGFloat(i) + colW / 2
            let frac = hi > lo ? (item.temp - lo) / (hi - lo) : 0.5
            let y = h - 8 - CGFloat(frac) * (h - 16)
            return CGPoint(x: x, y: y)
        }
        return ZStack {
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                if points.count > 2 {
                    for i in 1..<points.count {
                        let mid = CGPoint(x: (points[i - 1].x + points[i].x) / 2,
                                          y: (points[i - 1].y + points[i].y) / 2)
                        path.addQuadCurve(to: mid, control: points[i - 1])
                    }
                    if let last = points.last { path.addLine(to: last) }
                } else if points.count == 2 {
                    path.addLine(to: points[1])
                }
            }
            .stroke(Color(hex: "#FFD37F"), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            ForEach(points.indices, id: \.self) { pi in
                let p = points[pi]
                Circle()
                    .fill(Color(hex: "#FFD37F"))
                    .frame(width: 5, height: 5)
                    .position(p)
            }
        }
    }

    // MARK: - 15 日预报

    private func dailyCard(_ f: ForecastResponse) -> some View {
        let d = f.daily
        let weekMin = d.temperature_2m_min.min() ?? 0
        let weekMax = d.temperature_2m_max.max() ?? 1
        return Card(title: "15 日预报") {
            dailyTrend(d)
            Divider().overlay(.white.opacity(0.25))
            VStack(spacing: 10) {
                ForEach(d.time.indices, id: \.self) { i in
                    let dateStr = d.time[i]
                    HStack(spacing: 8) {
                        Text(weekdayText(dateStr, timezone: f.timezone, index: i))
                            .font(.subheadline)
                            .frame(width: 40, alignment: .leading)
                        WeatherIcon(code: d.weather_code[i], isDay: true, size: 26)
                            .frame(width: 24)
                        dailyPrecipText(d, i)
                            .font(.caption2)
                            .foregroundStyle(Color(hex: "#BFE0FF"))
                            .frame(width: 44, alignment: .leading)
                        Text("\(Int(d.temperature_2m_min[i].rounded()))°")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 32, alignment: .trailing)
                        rangeBar(min: d.temperature_2m_min[i], max: d.temperature_2m_max[i],
                                 weekMin: weekMin, weekMax: weekMax)
                            .frame(height: 5)
                        Text("\(Int(d.temperature_2m_max[i].rounded()))°")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 32, alignment: .trailing)
                    }
                }
            }
        }
    }

    /// 15 日高低温趋势双曲线（原版逐日卡的标志性样式：高点在上、低点在下，各带数值）
    private func dailyTrend(_ d: DailyWeather) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h: CGFloat = 78
            let n = d.time.count
            let lo = (d.temperature_2m_min.min() ?? 0) - 1.5
            let hi = (d.temperature_2m_max.max() ?? 1) + 1.5
            func pt(_ v: Double, _ i: Int) -> CGPoint {
                let x = n > 1 ? w * CGFloat(i) / CGFloat(n - 1) : w / 2
                let frac = hi > lo ? (v - lo) / (hi - lo) : 0.5
                return CGPoint(x: x, y: h - 16 - CGFloat(frac) * (h - 32))
            }
            let maxPts = d.temperature_2m_max.enumerated().map { pt($0.element, $0.offset) }
            let minPts = d.temperature_2m_min.enumerated().map { pt($0.element, $0.offset) }
            ZStack {
                smoothLine(maxPts)
                    .stroke(Color(hex: "#FFB35C"), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                smoothLine(minPts)
                    .stroke(Color(hex: "#7FD4FF"), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                ForEach(maxPts.indices, id: \.self) { i in
                    let p = maxPts[i]
                    Circle().fill(Color(hex: "#FFB35C")).frame(width: 4, height: 4).position(p)
                    Text("\(Int(d.temperature_2m_max[i].rounded()))°")
                        .font(.caption2)
                        .foregroundStyle(Color(hex: "#FFD9A8"))
                        .position(x: p.x, y: max(p.y - 10, 6))
                }
                ForEach(minPts.indices, id: \.self) { i in
                    let p = minPts[i]
                    Circle().fill(Color(hex: "#7FD4FF")).frame(width: 4, height: 4).position(p)
                    Text("\(Int(d.temperature_2m_min[i].rounded()))°")
                        .font(.caption2)
                        .foregroundStyle(Color(hex: "#CDEFFF"))
                        .position(x: p.x, y: min(p.y + 10, h - 6))
                }
            }
        }
        .frame(height: 78)
    }

    /// 平滑曲线路径（中点二次贝塞尔）
    private func smoothLine(_ points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            if points.count > 2 {
                for i in 1..<points.count {
                    let mid = CGPoint(x: (points[i - 1].x + points[i].x) / 2,
                                      y: (points[i - 1].y + points[i].y) / 2)
                    path.addQuadCurve(to: mid, control: points[i - 1])
                }
                if let last = points.last { path.addLine(to: last) }
            } else if points.count == 2 {
                path.addLine(to: points[1])
            }
        }
    }

    /// 日降水：有降水量显示 mm，否则显示降水概率
    private func dailyPrecipText(_ d: DailyWeather, _ i: Int) -> Text {
        if d.precipitation_sum[i] > 0.05 {
            return Text(String(format: "%.1fmm", d.precipitation_sum[i]))
        }
        if let arr = d.precipitation_probability_max, let p = arr[i] {
            return Text("\(p)%")
        }
        return Text("")
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

    // MARK: - 日出日落弧线

    private func sunCard(_ f: ForecastResponse) -> some View {
        Card(title: "日出日落") {
            let rise = f.daily.sunrise.first
            let set = f.daily.sunset.first
            VStack(spacing: 2) {
                GeometryReader { geo in
                    let w = geo.size.width
                    let horizon: CGFloat = 78
                    let r = w / 2 - 26
                    let cx = w / 2
                    let frac = sunFraction(f)
                    let theta = Double.pi * (1 - min(max(frac, 0), 1))
                    let sunX = cx + r * CGFloat(cos(theta))
                    let sunY = horizon - r * CGFloat(sin(theta))
                    ZStack {
                        // 太阳轨迹弧
                        Path { path in
                            path.addArc(center: CGPoint(x: cx, y: horizon), radius: r,
                                        startAngle: .degrees(180), endAngle: .degrees(0),
                                        clockwise: false)
                        }
                        .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        // 地平线
                        Path { path in
                            path.move(to: CGPoint(x: 6, y: horizon))
                            path.addLine(to: CGPoint(x: w - 6, y: horizon))
                        }
                        .stroke(.white.opacity(0.4), lineWidth: 1)
                        if frac >= 0 && frac <= 1 {
                            Circle()
                                .fill(Color(hex: "#FFD37F"))
                                .frame(width: 16, height: 16)
                                .shadow(color: Color(hex: "#FFD37F").opacity(0.8), radius: 6)
                                .position(x: sunX, y: sunY)
                        } else {
                            Image(systemName: "moon.stars.fill")
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 16))
                                .position(x: cx, y: 26)
                        }
                    }
                }
                .frame(height: 88)
                HStack {
                    Label("日出 \(hhmm(rise))", systemImage: "sunrise.fill")
                    Spacer()
                    Text(sunStatusText(f))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Label("日落 \(hhmm(set))", systemImage: "sunset.fill")
                }
                .font(.subheadline)
            }
        }
    }

    /// 当前时刻在日出-日落之间的比例（夜间返回 -1 或 2 表示区间外）
    private func sunFraction(_ f: ForecastResponse) -> Double {
        guard let riseStr = f.daily.sunrise.first,
              let setStr = f.daily.sunset.first,
              let rise = parseISO(riseStr, timezone: f.timezone),
              let set = parseISO(setStr, timezone: f.timezone),
              let now = parseISO(f.current.time, timezone: f.timezone) else { return -1 }
        let total = set.timeIntervalSince(rise)
        guard total > 0 else { return -1 }
        return now.timeIntervalSince(rise) / total
    }

    private func sunStatusText(_ f: ForecastResponse) -> String {
        let frac = sunFraction(f)
        if frac < 0 { return "日出前" }
        if frac > 1 { return "已日落" }
        guard let setStr = f.daily.sunset.first,
              let set = parseISO(setStr, timezone: f.timezone),
              let now = parseISO(f.current.time, timezone: f.timezone) else { return "" }
        let mins = Int(set.timeIntervalSince(now) / 60)
        return "距日落 \(mins / 60) 小时 \(mins % 60) 分"
    }

    // MARK: - 详情网格

    private func detailsGrid(_ f: ForecastResponse) -> some View {
        let idx = currentHourIndex(f)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
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
                Text("阵风 \(Int(c.wind_gusts_10m.rounded())) km/h · 风向 \(c.wind_direction_10m)°")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Card(title: "云量 · 降水") {
                Text("云量 \(f.current.cloud_cover)%")
                    .font(.headline)
                Text("当前降水 \(String(format: "%.1f", f.current.precipitation)) mm")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Card(title: "能见度") {
                if idx < f.hourly.visibility.count {
                    let km = f.hourly.visibility[idx] / 1000
                    Text(String(format: "%.1f km", km))
                        .font(.headline)
                    Text(km >= 20 ? "视野极佳" : (km >= 10 ? "视野良好" : (km >= 4 ? "视野一般" : "视野较差")))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    Text("暂无数据").font(.subheadline)
                }
            }
            Card(title: "露点") {
                if idx < f.hourly.dew_point_2m.count {
                    let dew = f.hourly.dew_point_2m[idx]
                    Text("\(Int(dew.rounded()))°")
                        .font(.headline)
                    Text(dewComfort(dew))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    Text("暂无数据").font(.subheadline)
                }
            }
        }
    }

    // MARK: - 生活指数

    private func lifeCard(_ f: ForecastResponse) -> some View {
        let c = f.current
        let probMax = f.daily.precipitation_probability_max?.first ?? nil
        let rainSum = f.daily.precipitation_sum.first ?? 0
        let aqi = air?.current.us_aqi
        let items: [(String, String, String)] = [
            ("穿衣", clothingAdvice(c.temperature_2m), "tshirt.fill"),
            ("洗车", (probMax ?? 0) >= 50 || rainSum > 0.2 ? "不宜" : "适宜", "car.fill"),
            ("运动", (aqi ?? 0) > 100 ? "不宜" : "适宜", "figure.run"),
            ("晾晒", (probMax ?? 0) >= 40 || c.relative_humidity_2m > 80 ? "不宜" : "适宜", "sun.max.fill"),
        ]
        return Card(title: "生活指数") {
            HStack(alignment: .top) {
                ForEach(items.indices, id: \.self) { ii in
                    let item = items[ii]
                    VStack(spacing: 5) {
                        Image(systemName: item.2)
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 20))
                        Text(item.1)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                        Text(item.0)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func clothingAdvice(_ temp: Double) -> String {
        switch temp {
        case ..<0: return "羽绒服"
        case ..<5: return "厚外套"
        case ..<10: return "外套"
        case ..<15: return "卫衣"
        case ..<20: return "长袖"
        case ..<26: return "短袖"
        default: return "清凉装"
        }
    }

    private func footer(_ f: ForecastResponse) -> some View {
        Text("数据来源：Open-Meteo · 更新于 \(String(f.current.time.dropFirst(11).prefix(5)))")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.6))
            .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func load() async {
        do {
            forecast = try await WeatherService.fetchForecast(for: city)
            errorText = nil
        } catch {
            if forecast == nil {
                let desc = (error as NSError).localizedDescription
                errorText = desc.isEmpty || desc.contains("data") ? "加载失败，请下拉重试" : "加载失败：\(desc)"
            }
        }
        air = try? await WeatherService.fetchAirQuality(for: city)
    }

    private func parseISO(_ s: String, timezone: String) -> Date? {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm"
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: timezone) ?? .current
        return parser.date(from: s)
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

    private func dewComfort(_ dew: Double) -> String {
        switch dew {
        case ..<10: return "空气干爽"
        case ..<16: return "体感舒适"
        case ..<18: return "略有闷感"
        case ..<21: return "闷热"
        default: return "非常闷热"
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
