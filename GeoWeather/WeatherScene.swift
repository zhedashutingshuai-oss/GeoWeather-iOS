import SwiftUI

/// 天气场景分类：首页动态背景与壁纸共用同一套场景语言
enum SceneKind {
    case clear, partly, cloudy, overcast, fog, drizzle, rain, heavyRain, snow, heavySnow, thunder, hail

    init(code: Int) {
        switch code {
        case 0: self = .clear
        case 1, 2: self = .partly
        case 3: self = .overcast
        case 45, 48: self = .fog
        case 51, 53, 55, 56, 57: self = .drizzle
        case 61, 80: self = .rain
        case 63: self = .rain
        case 65, 66, 67, 81, 82: self = .heavyRain
        case 71, 77, 85: self = .snow
        case 73, 75, 86: self = .heavySnow
        case 95: self = .thunder
        case 96, 99: self = .hail
        default: self = .cloudy
        }
    }

    func sky(isDay: Bool) -> (top: String, bottom: String) {
        switch (self, isDay) {
        case (.clear, true): return ("#2F6FD0", "#7FB4F2")
        case (.clear, false): return ("#0A1C3C", "#274B7A")
        case (.partly, true): return ("#3D7BDB", "#8FBDF2")
        case (.partly, false): return ("#12294D", "#33567F")
        case (.cloudy, true), (.overcast, true): return ("#66798E", "#A3B1BE")
        case (.cloudy, false), (.overcast, false): return ("#1C2836", "#46545F")
        case (.fog, true): return ("#79868F", "#B7BFC4")
        case (.fog, false): return ("#232B31", "#4C565E")
        case (.drizzle, true), (.rain, true): return ("#46586B", "#7E93A6")
        case (.drizzle, false), (.rain, false): return ("#131E2B", "#33424F")
        case (.heavyRain, true), (.thunder, true), (.hail, true): return ("#2E3D4E", "#5F7185")
        case (.heavyRain, false), (.thunder, false), (.hail, false): return ("#0C141E", "#27333F")
        case (.snow, true), (.heavySnow, true): return ("#7E97B5", "#C6D5E6")
        case (.snow, false), (.heavySnow, false): return ("#1E2C42", "#4A5C72")
        }
    }
}

/// 一朵云：几块椭圆叠出来的剪影
private struct CloudCluster: View {
    let width: CGFloat
    let tint: Color
    let opacity: Double

    var body: some View {
        ZStack {
            Ellipse().frame(width: width, height: width * 0.34)
            Ellipse().frame(width: width * 0.55, height: width * 0.46)
                .offset(x: -width * 0.17, y: -width * 0.10)
            Ellipse().frame(width: width * 0.46, height: width * 0.38)
                .offset(x: width * 0.21, y: -width * 0.06)
        }
        .foregroundStyle(tint)
        .opacity(opacity)
        .frame(width: width, height: width * 0.5)
    }
}

/// 天气场景：天空底色 + 日/月 + 云 + 雨/雪/雾粒子，随天气代码变化。
/// 首页用 animated 动态版，壁纸用静态版截一帧。
struct WeatherSceneView: View {
    let code: Int
    let isDay: Bool
    var animated: Bool = true
    /// 首页用：顶部压一层同色渐隐，让场景沉到标题文字后面、不糊字
    var topDim: Bool = false

    @State private var drift: CGFloat = -16

    private var kind: SceneKind { SceneKind(code: code) }

    /// 确定性伪随机（同一粒子位置稳定，不随重绘乱跳）
    private func rand(_ i: Int, _ salt: Int) -> Double {
        let v = sin(Double(i * 131 + salt * 197)) * 43758.5453
        return v - v.rounded(.down)
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let sky = kind.sky(isDay: isDay)
            ZStack {
                LinearGradient(colors: [Color(hex: sky.top), Color(hex: sky.bottom)],
                               startPoint: .top, endPoint: .bottom)

                if !isDay && (kind == .clear || kind == .partly) {
                    starCanvas(size)
                }

                celestial(size)

                clouds(size)

                if kind == .fog {
                    fogBands(size)
                }

                if kind == .thunder || kind == .hail {
                    bolt(size)
                }

                precipLayer(size)

                if topDim {
                    LinearGradient(colors: [Color(hex: sky.top).opacity(0.94),
                                            Color(hex: sky.top).opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: size.height * 0.44)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
                drift = 16
            }
        }
    }

    // MARK: - 日 / 月

    @ViewBuilder
    private func celestial(_ size: CGSize) -> some View {
        switch kind {
        case .clear, .partly:
            if isDay {
                SunIcon(size: min(size.width * 0.30, 120))
                    .position(x: size.width * 0.76, y: size.height * 0.17)
            } else {
                MoonView(phase: MoonPhase.now(), size: min(size.width * 0.20, 76))
                    .position(x: size.width * 0.76, y: size.height * 0.16)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - 云

    private func cloudTint(dark: Bool) -> Color {
        if dark { return isDay ? Color(hex: "#5F7185") : Color(hex: "#39434E") }
        return isDay ? .white : Color(hex: "#B9C7D8")
    }

    @ViewBuilder
    private func clouds(_ size: CGSize) -> some View {
        let w = size.width
        let d = animated ? drift : 0
        switch kind {
        case .clear:
            CloudCluster(width: w * 0.34, tint: cloudTint(dark: false), opacity: isDay ? 0.55 : 0.3)
                .position(x: w * 0.24 + d * 0.6, y: size.height * 0.15)
        case .partly:
            CloudCluster(width: w * 0.44, tint: cloudTint(dark: false), opacity: 0.85)
                .position(x: w * 0.30 + d, y: size.height * 0.16)
            CloudCluster(width: w * 0.30, tint: cloudTint(dark: false), opacity: 0.6)
                .position(x: w * 0.74 - d * 0.7, y: size.height * 0.09)
        case .cloudy, .snow, .heavySnow:
            CloudCluster(width: w * 0.52, tint: cloudTint(dark: false), opacity: 0.9)
                .position(x: w * 0.28 + d, y: size.height * 0.13)
            CloudCluster(width: w * 0.42, tint: cloudTint(dark: false), opacity: 0.75)
                .position(x: w * 0.72 - d * 0.8, y: size.height * 0.20)
            CloudCluster(width: w * 0.34, tint: cloudTint(dark: false), opacity: 0.55)
                .position(x: w * 0.55 + d * 0.5, y: size.height * 0.06)
        case .overcast, .fog:
            CloudCluster(width: w * 0.62, tint: cloudTint(dark: true), opacity: 0.55)
                .position(x: w * 0.26 + d * 0.7, y: size.height * 0.11)
            CloudCluster(width: w * 0.55, tint: cloudTint(dark: true), opacity: 0.5)
                .position(x: w * 0.74 - d * 0.6, y: size.height * 0.18)
        case .drizzle, .rain, .heavyRain, .thunder, .hail:
            CloudCluster(width: w * 0.58, tint: cloudTint(dark: true), opacity: 0.95)
                .position(x: w * 0.30 + d * 0.5, y: size.height * 0.11)
            CloudCluster(width: w * 0.48, tint: cloudTint(dark: true), opacity: 0.9)
                .position(x: w * 0.72 - d * 0.4, y: size.height * 0.16)
        }
    }

    // MARK: - 雾带

    private func fogBands(_ size: CGSize) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.white.opacity(0.13 + Double(i % 2) * 0.05))
                    .frame(width: size.width * 1.1, height: 26 + CGFloat(i) * 7)
                    .position(x: size.width * (i % 2 == 0 ? 0.42 : 0.58) + (animated ? drift * (i % 2 == 0 ? 1 : -1) : 0),
                              y: size.height * (0.34 + Double(i) * 0.15))
                    .blur(radius: 9)
            }
        }
    }

    // MARK: - 闪电

    private func bolt(_ size: CGSize) -> some View {
        Path { p in
            let x = size.width * 0.34, y = size.height * 0.20, s = size.width * 0.055
            p.move(to: CGPoint(x: x + s * 0.7, y: y))
            p.addLine(to: CGPoint(x: x - s * 0.5, y: y + s * 1.5))
            p.addLine(to: CGPoint(x: x + s * 0.1, y: y + s * 1.5))
            p.addLine(to: CGPoint(x: x - s * 0.6, y: y + s * 3.0))
            p.addLine(to: CGPoint(x: x + s * 1.1, y: y + s * 1.3))
            p.addLine(to: CGPoint(x: x + s * 0.5, y: y + s * 1.3))
            p.closeSubpath()
        }
        .fill(Color(hex: "#FFD94D"))
        .shadow(color: Color(hex: "#FFD94D").opacity(0.8), radius: 10)
        .opacity(0.9)
    }

    // MARK: - 星星

    private func starCanvas(_ size: CGSize) -> some View {
        Canvas { ctx, sz in
            for i in 0..<70 {
                let x = rand(i, 1) * sz.width
                let y = rand(i, 2) * sz.height * 0.55
                let r = 0.7 + rand(i, 3) * 1.3
                let rect = CGRect(x: x, y: y, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.25 + rand(i, 4) * 0.6)))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - 雨 / 雪粒子

    @ViewBuilder
    private func precipLayer(_ size: CGSize) -> some View {
        switch kind {
        case .drizzle, .rain, .heavyRain, .thunder, .hail, .snow, .heavySnow:
            if animated {
                TimelineView(.animation) { tl in
                    precipCanvas(size, time: tl.date.timeIntervalSinceReferenceDate)
                }
            } else {
                precipCanvas(size, time: 4.2)
            }
        default:
            EmptyView()
        }
    }

    private func precipCanvas(_ size: CGSize, time: Double) -> some View {
        Canvas { ctx, sz in
            switch kind {
            case .drizzle, .rain, .heavyRain, .thunder:
                let (count, len, speed): (Int, CGFloat, Double) =
                    kind == .drizzle ? (26, 9, 430) : kind == .rain ? (64, 13, 660) : (115, 17, 900)
                ctx.stroke(Path(), with: .color(.clear)) // 占位避免空分支警告
                for i in 0..<count {
                    let x = rand(i, 5) * (sz.width + 30)
                    let v = speed * (0.7 + 0.6 * rand(i, 6))
                    let y = (rand(i, 7) * sz.height + time * v).truncatingRemainder(dividingBy: Double(sz.height) + 30) - 15
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x - Double(len) * 0.22, y: y + Double(len)))
                    ctx.stroke(p, with: .color(.white.opacity(0.45)),
                               style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                }
            case .hail:
                for i in 0..<44 {
                    let x = rand(i, 5) * sz.width
                    let v = 950.0 * (0.7 + 0.6 * rand(i, 6))
                    let y = (rand(i, 7) * sz.height + time * v).truncatingRemainder(dividingBy: Double(sz.height) + 20) - 10
                    let r = 1.8 + rand(i, 8) * 1.6
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                             with: .color(.white.opacity(0.75)))
                }
            case .snow, .heavySnow:
                let count = kind == .snow ? 38 : 88
                let speed: Double = kind == .snow ? 52 : 84
                for i in 0..<count {
                    let baseX = rand(i, 5) * sz.width
                    let v = speed * (0.6 + 0.8 * rand(i, 6))
                    let y = (rand(i, 7) * sz.height + time * v).truncatingRemainder(dividingBy: Double(sz.height) + 16) - 8
                    let x = baseX + sin(time * 0.7 + rand(i, 9) * 6.28) * 11
                    let r = 1.4 + rand(i, 8) * 1.8
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                             with: .color(.white.opacity(0.85)))
                }
            default:
                break
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - 月相

struct MoonPhase {
    let age: Double
    let illumination: Double

    static let synodic = 29.530588853

    static func now() -> MoonPhase {
        // 基准朔月：2000-01-06 18:14 UTC
        let ref = Date(timeIntervalSince1970: 947_183_040)
        var age = Date().timeIntervalSince(ref) / 86400
        age = age.truncatingRemainder(dividingBy: synodic)
        if age < 0 { age += synodic }
        let illum = (1 - cos(2 * .pi * age / synodic)) / 2
        return MoonPhase(age: age, illumination: illum)
    }

    var name: String {
        let names = ["新月", "娥眉月", "上弦月", "盈凸月", "满月", "亏凸月", "下弦月", "残月"]
        return names[Int(age / MoonPhase.synodic * 8 + 0.5) % 8]
    }

    var waxing: Bool { age < MoonPhase.synodic / 2 }
}

/// 按月相画的月亮：亮盘 + 影圆错位，剪影即月相
struct MoonView: View {
    let phase: MoonPhase
    let size: CGFloat

    var body: some View {
        let illum = min(max(phase.illumination, 0), 1)
        let f = pow(sin(illum * .pi / 2), 0.8)
        let d = size * CGFloat(f)
        ZStack {
            Circle().fill(Color(hex: "#22314B"))
            Circle().fill(RadialGradient(colors: [Color(hex: "#F8F0D0"), Color(hex: "#E2CF92")],
                                         center: .center, startRadius: 0, endRadius: size * 0.52))
            Circle().fill(Color(hex: "#0E1B30").opacity(0.97))
                .offset(x: phase.waxing ? -d : d)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - 二十四节气（公历近似日期，误差 ±1 天）

enum SolarTerm {
    static let terms: [(name: String, month: Int, day: Int)] = [
        ("小寒", 1, 5), ("大寒", 1, 20), ("立春", 2, 4), ("雨水", 2, 19),
        ("惊蛰", 3, 5), ("春分", 3, 20), ("清明", 4, 5), ("谷雨", 4, 20),
        ("立夏", 5, 5), ("小满", 5, 21), ("芒种", 6, 5), ("夏至", 6, 21),
        ("小暑", 7, 7), ("大暑", 7, 22), ("立秋", 8, 7), ("处暑", 8, 23),
        ("白露", 9, 7), ("秋分", 9, 23), ("寒露", 10, 8), ("霜降", 10, 23),
        ("立冬", 11, 7), ("小雪", 11, 22), ("大雪", 12, 7), ("冬至", 12, 22),
    ]

    /// 当前节气、下一节气、距下一节气天数、今天是否正好是节气日
    static func current() -> (name: String, next: String, daysToNext: Int, isToday: Bool) {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let year = cal.component(.year, from: now)
        func makeDate(_ t: (name: String, month: Int, day: Int), _ y: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: t.month, day: t.day)) ?? now
        }
        var entries: [(String, Date)] = terms.map { ($0.name, makeDate($0, year)) }
        entries.append(("小寒", makeDate(terms[0], year + 1)))
        var name = "冬至"
        var next = "小寒"
        var nextDate = entries[0].1
        var isToday = false
        let todayStart = cal.startOfDay(for: now)
        for (i, e) in entries.enumerated() {
            if cal.startOfDay(for: e.1) == todayStart { isToday = true }
            if e.1 <= now, i + 1 < entries.count {
                name = e.0
                next = entries[i + 1].0
                nextDate = entries[i + 1].1
            }
        }
        let days = cal.dateComponents([.day], from: todayStart, to: cal.startOfDay(for: nextDate)).day ?? 0
        return (name, next, days, isToday)
    }

    static func displayText() -> String {
        let t = current()
        if t.isToday { return "今日\(t.name)" }
        if t.daysToNext == 1 { return "\(t.name) · 明日\(t.next)" }
        return "\(t.name) · 距\(t.next) \(t.daysToNext) 天"
    }
}

// MARK: - 农历（系统中文历）

enum LunarDate {
    static func displayText() -> String {
        let cal = Calendar(identifier: .chinese)
        let comps = cal.dateComponents([.month, .day, .isLeapMonth], from: Date())
        guard let month = comps.month, let day = comps.day else { return "" }
        let monthNames = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
        let dayNames = ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                        "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                        "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]
        guard (1...12).contains(month), (1...30).contains(day) else { return "" }
        let leap = (comps.isLeapMonth == true) ? "闰" : ""
        return "农历\(leap)\(monthNames[month - 1])月\(dayNames[day - 1])"
    }
}

// MARK: - 月出月落（suncalc 算法本地推算）
// 已与 weather.com 晋城数据对照（2026-11-21/22）：月出误差 +2 分钟、月落 +6~7 分钟

enum MoonTimes {
    static func riseSet(on date: Date, lat: Double, lon: Double, timeZone: TimeZone) -> (rise: Date?, set: Date?) {
        let rad = Double.pi / 180
        let e = rad * 23.4397
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let t0 = cal.startOfDay(for: date)
        func altitude(_ d: Date) -> Double {
            let days = d.timeIntervalSince1970 / 86400 - 0.5 + 2440588 - 2451545
            let L = rad * (218.316 + 13.176396 * days)
            let M = rad * (134.963 + 13.064993 * days)
            let F = rad * (93.272 + 13.229350 * days)
            let l = L + rad * 6.289 * sin(M)
            let b = rad * 5.128 * sin(F)
            let ra = atan2(sin(l) * cos(e) - tan(b) * sin(e), cos(l))
            let dec = asin(sin(b) * cos(e) + cos(b) * sin(e) * sin(l))
            let lw = rad * -lon
            let phi = rad * lat
            let H = (rad * (280.16 + 360.9856235 * days) - lw) - ra
            return asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(H))
        }
        let hc = 0.133 * rad
        var h0 = altitude(t0) - hc
        var rise: Date?
        var set: Date?
        var i = 1
        while i <= 24 {
            let h1 = altitude(t0.addingTimeInterval(Double(i) * 3600)) - hc
            let h2 = altitude(t0.addingTimeInterval(Double(i + 1) * 3600)) - hc
            let a = (h0 + h2) / 2 - h1
            let b = (h2 - h0) / 2
            let xe = a != 0 ? -b / (2 * a) : 0
            let ye = (a * xe + b) * xe + h1
            let disc = b * b - 4 * a * h1
            var roots = 0
            var x1 = 0.0
            var x2 = 0.0
            if disc >= 0 && a != 0 {
                let dx = sqrt(disc) / (abs(a) * 2)
                x1 = xe - dx
                x2 = xe + dx
                if abs(x1) <= 1 { roots += 1 }
                if abs(x2) <= 1 { roots += 1 }
                if x1 < -1 { x1 = x2 }
            }
            if roots == 1 {
                if h0 < 0 { rise = t0.addingTimeInterval((Double(i) + x1) * 3600) }
                else { set = t0.addingTimeInterval((Double(i) + x1) * 3600) }
            } else if roots == 2 {
                rise = t0.addingTimeInterval((Double(i) + (ye < 0 ? x2 : x1)) * 3600)
                set = t0.addingTimeInterval((Double(i) + (ye < 0 ? x1 : x2)) * 3600)
            }
            if rise != nil && set != nil { break }
            h0 = h2
            i += 2
        }
        return (rise, set)
    }
}

// MARK: - 外观模式（浅色 / 深色 / 跟随手机）

enum AppearanceHelper {
    static func isNight(mode: String, scheme: ColorScheme) -> Bool {
        switch mode {
        case "light": return false
        case "dark": return true
        default: return scheme == .dark
        }
    }

    static func pageGradient(night: Bool) -> [Color] {
        night ? [Color(hex: "#0A1830"), Color(hex: "#1D3358")]
              : [Color(hex: "#3D7BDB"), Color(hex: "#7FB2F0")]
    }
}
