import SwiftUI
import WidgetKit

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

enum AppSection: CaseIterable {
    case weather, wallpaper, tools, about

    var label: String {
        switch self {
        case .weather: return "天气"
        case .wallpaper: return "壁纸"
        case .tools: return "工具"
        case .about: return "关于"
        }
    }

    var icon: String {
        switch self {
        case .weather: return "cloud.sun.fill"
        case .wallpaper: return "photo.fill"
        case .tools: return "safari.fill"
        case .about: return "info.circle.fill"
        }
    }
}

struct ContentView: View {
    @State private var section: AppSection = .weather

    var body: some View {
        // 系统原生标签栏：iOS 26 起自带液态玻璃悬浮胶囊与滑动选中药丸
        TabView(selection: $section) {
            Tab("天气", systemImage: "cloud.sun.fill", value: AppSection.weather) {
                WeatherHomeView()
            }
            Tab("壁纸", systemImage: "photo.fill", value: AppSection.wallpaper) {
                WallpaperView()
            }
            Tab("工具", systemImage: "safari.fill", value: AppSection.tools) {
                ToolsView()
            }
            Tab("关于", systemImage: "info.circle.fill", value: AppSection.about) {
                AboutView()
            }
        }
        .tabBarMinimizeBehavior(.never)
    }
}

struct WeatherHomeView: View {
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
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

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
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(AppearanceHelper.isNight(mode: appearanceMode, scheme: colorScheme)
                                   ? Color(hex: "#04091D").opacity(0.55)
                                   : Color(hex: "#0A2A5E").opacity(0.25)),
                     in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// 子页面统一背景：随外观模式变色
struct PageGradient: View {
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(colors: AppearanceHelper.pageGradient(
                        night: AppearanceHelper.isNight(mode: appearanceMode, scheme: colorScheme)),
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

/// 原版几何天气图标：静态图，或帧动画（大图标用）
private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

/// 程序绘制的太阳：原版晴天图标只有 3 帧，帧动画再溶接也有天花板；
/// 这里用矢量菱形光芒＋圆盘，旋转与呼吸都是连续动画，按屏幕刷新率渲染（120Hz 屏即满帧）。
struct SunIcon: View {
    var size: CGFloat
    @State private var spinning = false
    @State private var pulsing = false

    var body: some View {
        ZStack {
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    Diamond()
                        .fill(LinearGradient(colors: [Color(hex: "#FFB84D"), Color(hex: "#FF9435")],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: size * 0.30, height: size * 0.38)
                        .offset(y: -size * 0.30)
                        .rotationEffect(.degrees(Double(i) * 45))
                }
            }
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .scaleEffect(pulsing ? 1.05 : 0.95)

            Circle()
                .fill(RadialGradient(colors: [Color(hex: "#FFE9A8"), Color(hex: "#FFD35C")],
                                     center: .center, startRadius: 0, endRadius: size * 0.31))
                .frame(width: size * 0.62, height: size * 0.62)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) {
                spinning = true
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}

struct WeatherIcon: View {
    let code: Int
    let isDay: Bool
    var size: CGFloat = 24
    var animated: Bool = false

    @State private var frameIndex = 0

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
        if animated && code == 0 && isDay {
            // 晴天太阳走程序绘制的连续动画，不用 3 帧 PNG
            SunIcon(size: size)
        } else if animated {
            let frames = WeatherCode.iconFrames(code, isDay: isDay)
            if frames.count > 1 {
                // 帧间交叉淡入淡出代替硬切：原版每种天气只有 3~4 帧，硬切像幻灯片，溶接后顺滑得多
                ZStack {
                    iconImage(frames[frameIndex % frames.count])
                        .id(frameIndex % frames.count)
                        .transition(.opacity)
                }
                .frame(width: size, height: size)
                .animation(.easeInOut(duration: 0.45), value: frameIndex)
                .task {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 550_000_000)
                        frameIndex += 1
                    }
                }
            } else {
                iconImage(frames.first ?? WeatherCode.iconName(code, isDay: isDay))
                    .frame(width: size, height: size)
            }
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
    /// 非 nil 表示当前展示的是缓存数据（网络不佳时的兜底），值为缓存保存时间
    @State private var staleAt: Date?
    @State private var show15Days = false
    @Namespace private var rangeNS
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @Environment(\.colorScheme) private var colorScheme
    @State private var hourMetric = 0
    @Namespace private var metricNS
    @State private var radarFrames: [RadarFrame] = []
    @State private var showRadar = false
    @State private var backup: BackupWeather?

    private var nightMode: Bool {
        AppearanceHelper.isNight(mode: appearanceMode, scheme: colorScheme)
    }

    var body: some View {
        ZStack {
            WeatherSceneView(code: forecast?.current.weather_code ?? 0,
                             isDay: !nightMode,
                             animated: true,
                             topDim: true)
                .ignoresSafeArea()

            ScrollView {
                GlassEffectContainer(spacing: 14) {
                VStack(spacing: 14) {
                    header
                    if let f = forecast {
                        currentCard(f)
                        if let m = f.minutely_15, !m.precipitation.isEmpty {
                            precipCard(f, m)
                        }
                        radarCard
                        dailyCard(f)
                        hourlyCard(f)
                        if let a = air {
                            aqiCard(a)
                        }
                        sunCard(f)
                        detailsGrid(f)
                        lifeCard(f)
                        footer(f)
                    } else if let b = backup {
                        backupCards(b)
                        radarCard
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
                .padding(.bottom, 28)
                }
            }
            .refreshable { await load() }

            topScrim
        }
        .task(id: city.id) { await load() }
        .task {
            if radarFrames.isEmpty {
                radarFrames = (try? await RadarService.fetchFrames()) ?? []
            }
        }
        .fullScreenCover(isPresented: $showRadar) {
            RadarFullView(frames: radarFrames)
        }
        .task(id: errorText) {
            guard errorText != nil else { return }
            while !Task.isCancelled && forecast == nil {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                if Task.isCancelled || forecast != nil { break }
                await load()
            }
        }
        .task(id: backup != nil) {
            guard backup != nil else { return }
            while !Task.isCancelled && backup != nil {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                if Task.isCancelled || backup == nil { break }
                await load()
            }
        }
    }

    private var gradientPair: (top: String, bottom: String) {
        if let c = forecast?.current {
            return WeatherCode.gradient(c.weather_code, isDay: !nightMode)
        }
        return ("#3D7BDB", "#7FB2F0")
    }

    /// 顶部渐隐罩：内容滚到状态栏/按钮下方时不糊字
    private var topScrim: some View {
        LinearGradient(colors: [Color(hex: gradientPair.top).opacity(0.92),
                                Color(hex: gradientPair.top).opacity(0)],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: 120)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
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
            Text("\(SolarTerm.displayText()) · \(LunarDate.displayText())")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
            if let staleAt {
                Text("网络不佳 · 显示 \(hhmmString(staleAt)) 的缓存")
                    .font(.caption)
                    .foregroundStyle(.yellow.opacity(0.95))
            }
        }
        .frame(maxWidth: .infinity)
        .shadow(color: .black.opacity(0.22), radius: 3, x: 0, y: 1)
    }

    // MARK: - 当前天气

    private func currentCard(_ f: ForecastResponse) -> some View {
        let c = f.current
        return Card(title: "当前天气") {
            HStack(alignment: .center, spacing: 16) {
                // 当前卡只要数据：不放天气图标（用户 2026-11-21 定）
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
                VStack(alignment: .trailing, spacing: 6) {
                    if let hi = f.daily.temperature_2m_max.first, let lo = f.daily.temperature_2m_min.first {
                        Label("\(Int(hi.rounded()))°", systemImage: "arrow.up")
                        Label("\(Int(lo.rounded()))°", systemImage: "arrow.down")
                    }
                    Label("\(compass(c.wind_direction_10m))风", systemImage: "safari")
                    Label("云量 \(c.cloud_cover)%", systemImage: "cloud")
                    if c.precipitation > 0 {
                        Label("降水 \(String(format: "%.1f", c.precipitation)) mm", systemImage: "drop")
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
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
        let wind: Double
        let uv: Double
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
                     precip: f.hourly.precipitation_probability?[i] ?? nil,
                     wind: f.hourly.wind_speed_10m?[safe: i] ?? 0,
                     uv: f.hourly.uv_index?[safe: i] ?? 0)
        }
    }

    private func hourlyCard(_ f: ForecastResponse) -> some View {
        let items = next24Hours(f)
        let colW: CGFloat = 54
        let metricNames = ["温度", "降水", "风速", "紫外线"]
        let metricColors = [Color(hex: "#FFD37F"), Color(hex: "#7FD4FF"), Color(hex: "#9FE8C1"), Color(hex: "#FFB35C")]
        let metricUnits = ["°", "%", " km/h", ""]
        let values: [Double] = {
            switch hourMetric {
            case 1: return items.map { Double($0.precip ?? 0) }
            case 2: return items.map(\.wind)
            case 3: return items.map(\.uv)
            default: return items.map(\.temp)
            }
        }()
        return Card(title: "逐小时预报") {
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    HStack(spacing: 0) {
                        ForEach(metricNames.indices, id: \.self) { mi in
                            Button {
                                withAnimation(.easeInOut(duration: 0.22)) { hourMetric = mi }
                            } label: {
                                Text(metricNames[mi])
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(hourMetric == mi ? .white : .white.opacity(0.6))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background {
                                        if hourMetric == mi {
                                            Capsule()
                                                .fill(Color.white.opacity(0.32))
                                                .matchedGeometryEffect(id: "metricPill", in: metricNS)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .glassEffect(.regular, in: Capsule())
                }
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
                        metricCurve(values: values, color: metricColors[hourMetric], colW: colW)
                            .frame(width: colW * CGFloat(items.count), height: 46)
                    }
                }
                if let lo = values.min(), let hi = values.max() {
                    Text("\(metricNames[hourMetric])区间：\(Int(lo.rounded()))\(metricUnits[hourMetric]) ~ \(Int(hi.rounded()))\(metricUnits[hourMetric])")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
        }
    }

    /// 通用指标曲线：平滑折线 + 数据点（温度/降水/风速/紫外线共用）
    private func metricCurve(values: [Double], color: Color, colW: CGFloat) -> some View {
        let lo = (values.min() ?? 0) - 1
        let hi = (values.max() ?? 1) + 1
        let h: CGFloat = 46
        let points: [CGPoint] = values.enumerated().map { i, v in
            let x = colW * CGFloat(i) + colW / 2
            let frac = hi > lo ? (v - lo) / (hi - lo) : 0.5
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
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            ForEach(points.indices, id: \.self) { pi in
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .position(points[pi])
            }
        }
    }

    // MARK: - 15 日预报

    /// 7 日 / 15 日切换（液态玻璃分段）
    private var rangeToggle: some View {
        HStack(spacing: 0) {
            ForEach([7, 15], id: \.self) { days in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { show15Days = (days == 15) }
                } label: {
                    Text("\(days) 日")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(show15Days == (days == 15) ? .white : .white.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background {
                            if show15Days == (days == 15) {
                                Capsule()
                                    .fill(Color.white.opacity(0.32))
                                    .matchedGeometryEffect(id: "rangePill", in: rangeNS)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .glassEffect(.regular, in: Capsule())
    }

    private func dailyCard(_ f: ForecastResponse) -> some View {
        let full = f.daily
        let n = show15Days ? full.time.count : min(7, full.time.count)
        let d = DailyWeather(
            time: Array(full.time.prefix(n)),
            weather_code: Array(full.weather_code.prefix(n)),
            temperature_2m_max: Array(full.temperature_2m_max.prefix(n)),
            temperature_2m_min: Array(full.temperature_2m_min.prefix(n)),
            sunrise: Array(full.sunrise.prefix(n)),
            sunset: Array(full.sunset.prefix(n)),
            uv_index_max: Array(full.uv_index_max.prefix(n)),
            precipitation_probability_max: full.precipitation_probability_max.map { Array($0.prefix(n)) },
            precipitation_sum: Array(full.precipitation_sum.prefix(n)),
            wind_speed_10m_max: Array(full.wind_speed_10m_max.prefix(n)))
        let weekMin = d.temperature_2m_min.min() ?? 0
        let weekMax = d.temperature_2m_max.max() ?? 1
        return Card(title: show15Days ? "15 日预报" : "7 日预报") {
            VStack(spacing: 10) {
                HStack {
                    Spacer()
                    rangeToggle
                }
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
    }

    /// 15 日高低温趋势双曲线（原版逐日卡的标志性样式：高点在上、低点在下，各带数值）
    private func dailyTrend(_ d: DailyWeather) -> some View {
        GeometryReader { geo in
            dailyTrendCanvas(d, width: geo.size.width)
        }
        .frame(height: 78)
    }

    private func dailyTrendCanvas(_ d: DailyWeather, width: CGFloat) -> some View {
        let h: CGFloat = 78
        let maxPts = trendPoints(d.temperature_2m_max, in: d, width: width, height: h)
        let minPts = trendPoints(d.temperature_2m_min, in: d, width: width, height: h)
        return ZStack {
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

    /// 把温度序列映射成图上的点（纯计算，放在 ViewBuilder 之外，避免编译器类型推断卡死）
    private func trendPoints(_ values: [Double], in d: DailyWeather, width: CGFloat, height: CGFloat) -> [CGPoint] {
        let n = values.count
        let lo = (d.temperature_2m_min.min() ?? 0) - 1.5
        let hi = (d.temperature_2m_max.max() ?? 1) + 1.5
        return values.enumerated().map { i, v in
            let x = n > 1 ? 8 + (width - 16) * CGFloat(i) / CGFloat(n - 1) : width / 2
            let frac = hi > lo ? (v - lo) / (hi - lo) : 0.5
            return CGPoint(x: x, y: height - 16 - CGFloat(frac) * (height - 32))
        }
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
                    let r = min(w / 2 - 26, 66)
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
                .clipped()
                HStack {
                    Label("日出 \(hhmm(rise))", systemImage: "sunrise.fill")
                    Spacer()
                    Text(sunStatusText(f))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Label("日落 \(hhmm(set))", systemImage: "sunset.fill")
                }
                .font(.subheadline)
                Divider().overlay(.white.opacity(0.3))
                HStack(spacing: 12) {
                    let phase = MoonPhase.now()
                    MoonView(phase: phase, size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("月相 · \(phase.name)")
                            .font(.subheadline.weight(.medium))
                        Text("照亮 \(Int(phase.illumination * 100))% · 月龄 \(String(format: "%.1f", phase.age)) 天")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        let mtz = TimeZone(identifier: f.timezone) ?? .current
                        let mt = MoonTimes.riseSet(on: Date(), lat: city.latitude, lon: city.longitude, timeZone: mtz)
                        Text("月出 \(mt.rise.map { hhmmTZ($0, mtz) } ?? "—") · 月落 \(mt.set.map { hhmmTZ($0, mtz) } ?? "—")（本地推算）")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                }
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

    // MARK: - 降水预报（逐 15 分钟）

    /// 备用源（中国天气网）整套卡片：主源断连且无缓存时展示
    private func backupCards(_ b: BackupWeather) -> some View {
        Group {
            if !b.alarms.isEmpty {
                Card(title: "气象预警") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(b.alarms, id: \.self) { alarm in
                            Text("⚠ \(alarm)")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            Card(title: "当前天气") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(b.temp.rounded()))°")
                                .font(.system(size: 64, weight: .thin))
                            Text(b.weatherText)
                                .font(.headline)
                            if !b.todayText.isEmpty {
                                Text("今日 \(b.todayText)")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 7) {
                            if let today = b.days.first {
                                Label("\(Int(today.hi.rounded()))°", systemImage: "arrow.up")
                                Label("\(Int(today.lo.rounded()))°", systemImage: "arrow.down")
                            }
                            Text(b.windText)
                                .multilineTextAlignment(.trailing)
                        }
                        .font(.subheadline)
                    }
                    Divider().overlay(.white.opacity(0.25))
                    HStack {
                        VStack(spacing: 2) {
                            Text("\(b.humidity)%").font(.headline)
                            Text("湿度").font(.caption).foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text(b.visibility.isEmpty ? "—" : b.visibility).font(.headline)
                            Text("能见度").font(.caption).foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text(b.aqi.map { "\($0)" } ?? "—").font(.headline)
                            Text("空气质量 AQI").font(.caption).foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text(b.pm25.map { "\($0)" } ?? "—").font(.headline)
                            Text("PM2.5").font(.caption).foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
            }
            if !b.days.isEmpty {
                Card(title: "5 日预报") {
                    VStack(spacing: 12) {
                        let weekMin = b.days.map(\.lo).min() ?? 0
                        let weekMax = b.days.map(\.hi).max() ?? 1
                        ForEach(b.days) { d in
                            backupDayRow(d, weekMin: weekMin, weekMax: weekMax)
                        }
                    }
                }
            }
            if !b.indices.isEmpty {
                Card(title: "生活指数") {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(Array(b.indices.enumerated()), id: \.offset) { _, item in
                            HStack {
                                Text(item.name)
                                    .font(.subheadline)
                                Spacer()
                                Text(item.hint)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        }
                    }
                }
            }
            Text("备用数据源 · 中国天气网（主源暂时连不上，已自动切换；观测时间 \(b.obsTime)）")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func backupDayRow(_ d: BackupDay, weekMin: Double, weekMax: Double) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(d.label).font(.subheadline)
                Text(d.dateText).font(.caption2).foregroundStyle(.white.opacity(0.7))
            }
            .frame(width: 54, alignment: .leading)
            WeatherIcon(code: d.dayCode, isDay: true, size: 26, animated: false)
            Text("\(Int(d.lo.rounded()))°")
                .font(.subheadline)
                .frame(width: 34, alignment: .trailing)
            GeometryReader { geo in
                let span = max(1, weekMax - weekMin)
                let x0 = (d.lo - weekMin) / span * geo.size.width
                let w = max(8, (d.hi - d.lo) / span * geo.size.width)
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule()
                        .fill(LinearGradient(colors: [.cyan, .orange], startPoint: .leading, endPoint: .trailing))
                        .frame(width: w)
                        .offset(x: x0)
                }
            }
            .frame(height: 5)
            Text("\(Int(d.hi.rounded()))°")
                .font(.subheadline)
                .frame(width: 34, alignment: .leading)
        }
    }

    /// 实时雨云卡：中央气象台全国雷达拼图最新一帧，点开看大图与动画
    private var radarCard: some View {
        Card(title: "实时雨云 · 全国雷达") {
            VStack(alignment: .leading, spacing: 8) {
                if let last = radarFrames.last {
                    RadarImageView(url: last.url)
                        .aspectRatio(825.0 / 739.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    HStack {
                        Text("最新一帧 \(RadarTime.label(last.time))")
                        Spacer()
                        Text("点开看动画 ›")
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                } else {
                    Text("雷达图加载中…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !radarFrames.isEmpty { showRadar = true } }
    }

    private func precipCard(_ f: ForecastResponse, _ m: MinutelyWeather) -> some View {
        let start = m.time.firstIndex(where: { $0 >= f.current.time }) ?? max(0, m.time.count - 8)
        let end = min(start + 8, m.time.count)
        let values = Array(m.precipitation[start..<end])
        let times = Array(m.time[start..<end])
        let wet = values.indices.filter { values[$0] >= 0.1 }
        let summary: String = {
            guard let firstWet = wet.first, let lastWet = wet.last else {
                return "未来 2 小时无降水"
            }
            if firstWet == 0 {
                if lastWet == values.count - 1 { return "降水持续中，2 小时内不会停" }
                return "正在降水，预计 \(hhmm(times[lastWet + 1])) 前后停"
            }
            var s = "约 \(firstWet * 15) 分钟后开始降水"
            if lastWet < values.count - 1 { s += "，\(hhmm(times[lastWet + 1])) 前后停" }
            return s
        }()
        return Card(title: "降水预报") {
            VStack(alignment: .leading, spacing: 10) {
                Text(summary)
                    .font(.subheadline.weight(.medium))
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(values.indices, id: \.self) { i in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(values[i] >= 0.1 ? Color(hex: "#7FD4FF") : Color.white.opacity(0.22))
                                .frame(height: 6 + min(38, CGFloat(values[i]) * 9))
                            Text(hhmm(times[i]))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - 空气质量分项

    private func aqiCard(_ a: AirQualityResponse) -> some View {
        let c = a.current
        let rows: [(String, Double?, Double)] = [
            ("PM2.5", c.pm2_5, 75),
            ("PM10", c.pm10, 150),
            ("二氧化氮", c.nitrogen_dioxide, 80),
            ("二氧化硫", c.sulphur_dioxide, 150),
            ("臭氧", c.ozone, 160),
            ("一氧化碳", c.carbon_monoxide, 4000),
        ]
        return Card(title: "空气质量") {
            VStack(alignment: .leading, spacing: 10) {
                if let aqi = c.us_aqi {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(Int(aqi.rounded()))")
                            .font(.system(size: 34, weight: .semibold))
                        Text("US AQI · \(aqiCategory(aqi))")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                ForEach(rows, id: \.0) { row in
                    if let v = row.1 {
                        HStack(spacing: 10) {
                            Text(row.0)
                                .font(.subheadline)
                                .frame(width: 62, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.16))
                                    Capsule()
                                        .fill(barColor(v / row.2))
                                        .frame(width: max(4, geo.size.width * min(1, v / row.2)))
                                }
                            }
                            .frame(height: 7)
                            Text("\(Int(v.rounded()))")
                                .font(.subheadline.weight(.medium))
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                Text("单位 µg/m³ · 条长按国标日均限值比例")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private func barColor(_ frac: Double) -> Color {
        if frac < 0.34 { return Color(hex: "#6FCF97") }
        if frac < 0.67 { return Color(hex: "#FFD94D") }
        return Color(hex: "#FF8A5C")
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

    private func hhmmTZ(_ d: Date, _ tz: TimeZone) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.timeZone = tz
        return fmt.string(from: d)
    }

    private func hhmmString(_ d: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: d)
    }

    private func load() async {
        // 冷启动先垫缓存，页面立刻有内容，再等网络刷新
        if forecast == nil, let cached = ForecastCache.load(for: city) {
            forecast = cached.forecast
            staleAt = cached.savedAt
        }
        do {
            let f = try await WeatherService.fetchForecast(for: city)
            forecast = f
            backup = nil
            errorText = nil
            staleAt = nil
            ForecastCache.save(f, for: city)
            SharedSnapshotStore.save(SharedSnapshot.make(from: f, city: city))
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            if let cached = ForecastCache.load(for: city) {
                // 重试后仍失败：用缓存兜底，不整页报错
                forecast = cached.forecast
                staleAt = cached.savedAt
                errorText = nil
            } else if forecast == nil {
                // 主源与缓存都不可用：切国内备用源（中国天气网）兜底
                do {
                    backup = try await BackupService.fetch(for: city)
                    errorText = nil
                } catch let e as BackupFailure {
                    errorText = "网络连接失败，正在自动重试…（也可以下拉刷新）\n备用源未接通：\(e.stage)"
                } catch {
                    errorText = "网络连接失败，正在自动重试…（也可以下拉刷新）"
                }
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
