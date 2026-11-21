import Foundation

/// 国内备用源：中国天气网（weather.com.cn 内部数据接口，未公开、可能随其改版失效，仅作兜底）
/// 流程：坐标 → d4 接口换 areaid → d1 weather_index 拿实况/5日预报/生活指数/预警。
/// 2026-11-21 用户拍板双源兜底：Open-Meteo 主源连不上且无缓存时自动切换，页面标注备用源。
struct BackupDay: Identifiable {
    let label: String
    let dateText: String
    let dayCode: Int
    let hi: Double
    let lo: Double
    let windText: String
    var id: String { dateText + label }
}

struct BackupWeather {
    let temp: Double
    let weatherText: String
    let windText: String
    let humidity: Int
    let visibility: String
    let aqi: Int?
    let pm25: Int?
    let obsTime: String
    let todayText: String
    let days: [BackupDay]
    let indices: [(name: String, hint: String)]
    let alarms: [String]
}

enum BackupService {
    static func fetch(for city: City) async throws -> BackupWeather {
        let params = "{\"method\":\"stationinfo\",\"lat\":\(city.latitude),\"lng\":\(city.longitude),\"callback\":\"getData\"}"
        let encoded = params.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? params
        guard let geoURL = URL(string: "https://d4.weather.com.cn/geong/v1/api?params=\(encoded)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: geoURL)
        req.setValue("https://www.weather.com.cn/", forHTTPHeaderField: "Referer")
        let (d1, _) = try await URLSession.shared.data(for: req)
        let t1 = String(decoding: d1, as: UTF8.self)
        guard let areaid = firstCapture(#""areaid":"(\d+)""#, in: t1) else {
            throw URLError(.cannotParseResponse)
        }
        guard let dataURL = URL(string: "https://d1.weather.com.cn/weather_index/\(areaid).html") else {
            throw URLError(.badURL)
        }
        var req2 = URLRequest(url: dataURL)
        req2.setValue("https://www.weather.com.cn/weather/\(areaid).shtml", forHTTPHeaderField: "Referer")
        req2.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15",
                      forHTTPHeaderField: "User-Agent")
        let (d2, _) = try await URLSession.shared.data(for: req2)
        return try parse(String(decoding: d2, as: UTF8.self))
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges > 1 else { return nil }
        return ns.substring(with: m.range(at: 1))
    }

    /// 从 JS 文本里抠出 `var name = {...}` 并 JSON 解析（按括号配平扫描，跳过字符串内括号）
    private static func extractVar(_ name: String, in text: String) -> Any? {
        guard let anchor = text.range(of: "var \(name) =") ?? text.range(of: "var \(name)=") else { return nil }
        let rest = text[anchor.upperBound...]
        guard let start = rest.firstIndex(where: { $0 == "{" || $0 == "[" }) else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        var idx = start
        while idx < rest.endIndex {
            let ch = rest[idx]
            if inString {
                if escaped { escaped = false }
                else if ch == "\\" { escaped = true }
                else if ch == "\"" { inString = false }
            } else {
                if ch == "\"" { inString = true }
                else if ch == "{" || ch == "[" { depth += 1 }
                else if ch == "}" || ch == "]" {
                    depth -= 1
                    if depth == 0 {
                        let jsonText = String(rest[start...idx])
                        guard let data = jsonText.data(using: .utf8) else { return nil }
                        return try? JSONSerialization.jsonObject(with: data)
                    }
                }
            }
            idx = rest.index(after: idx)
        }
        return nil
    }

    private static func parse(_ text: String) throws -> BackupWeather {
        guard let sk = extractVar("dataSK", in: text) as? [String: Any],
              let temp = Double(sk["temp"] as? String ?? "") else {
            throw URLError(.cannotParseResponse)
        }
        let dz = (extractVar("cityDZ", in: text) as? [String: Any])?["weatherinfo"] as? [String: Any]
        let fcRoot = extractVar("fc", in: text) as? [String: Any]
        let fArr = fcRoot?["f"] as? [[String: Any]] ?? []
        let days: [BackupDay] = fArr.map { d in makeDay(d) }
        // 生活指数：dataZS.zs 里 *_name / *_hint 成对出现，按常用顺序取
        var indices: [(name: String, hint: String)] = []
        if let zs = (extractVar("dataZS", in: text) as? [String: Any])?["zs"] as? [String: Any] {
            for key in ["ct", "uv", "gm", "co", "yd", "cl", "tr", "pl", "lk", "wc", "gl", "gj", "hc", "pj"] {
                if let n = zs["\(key)_name"] as? String, let h = zs["\(key)_hint"] as? String {
                    indices.append((name: n, hint: h))
                }
            }
        }
        // 预警：alarmDZ.w 数组，取每条里含「预警」的最长字符串
        var alarms: [String] = []
        if let w = (extractVar("alarmDZ", in: text) as? [String: Any])?["w"] as? [[String: Any]] {
            for item in w {
                let strings = item.values.compactMap { $0 as? String }
                if let hit = strings.filter({ $0.contains("预警") }).max(by: { $0.count < $1.count }) {
                    alarms.append(hit)
                }
            }
        }
        let humidityText = (sk["SD"] as? String ?? "").replacingOccurrences(of: "%", with: "")
        let windParts = [sk["WD"] as? String ?? "", sk["WS"] as? String ?? ""].filter { !$0.isEmpty }
        var windText = windParts.joined(separator: " ")
        if let wse = sk["wse"] as? String, !wse.isEmpty { windText += "（\(wse)）" }
        return BackupWeather(
            temp: temp,
            weatherText: sk["weather"] as? String ?? "",
            windText: windText,
            humidity: Int(humidityText) ?? 0,
            visibility: sk["njd"] as? String ?? "",
            aqi: Int(sk["aqi"] as? String ?? ""),
            pm25: Int(sk["aqi_pm25"] as? String ?? ""),
            obsTime: sk["time"] as? String ?? "",
            todayText: dz?["weather"] as? String ?? "",
            days: days,
            indices: indices,
            alarms: alarms
        )
    }

    private static func makeDay(_ d: [String: Any]) -> BackupDay {
        let windDir = d["fe"] as? String ?? ""
        let windForce = d["fg"] as? String ?? ""
        let wind = (windDir + " " + windForce).trimmingCharacters(in: .whitespaces)
        return BackupDay(
            label: d["fj"] as? String ?? "",
            dateText: d["fi"] as? String ?? "",
            dayCode: mapCode(d["fa"] as? String ?? ""),
            hi: Double(d["fc"] as? String ?? "") ?? 0,
            lo: Double(d["fd"] as? String ?? "") ?? 0,
            windText: wind
        )
    }

    /// 中国天气网天气代码 → WMO 代码（供现有图标/文字体系使用）
    private static func mapCode(_ s: String) -> Int {
        switch s {
        case "00": return 0
        case "01": return 2
        case "02": return 3
        case "03": return 80
        case "04": return 95
        case "05": return 96
        case "06": return 85
        case "07": return 61
        case "08", "21": return 63
        case "09", "10", "11", "12", "22", "23", "24", "25": return 65
        case "13": return 85
        case "14", "26": return 71
        case "15", "27": return 73
        case "16", "17", "28": return 75
        case "18", "19", "20", "29", "30", "31", "53": return 45
        default: return 3
        }
    }
}
