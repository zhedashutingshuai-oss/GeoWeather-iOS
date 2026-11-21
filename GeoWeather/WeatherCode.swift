import Foundation

/// WMO 天气代码 → 中文描述与 SF Symbol（Open-Meteo 使用 WMO 代码表）
enum WeatherCode {
    static func text(_ code: Int) -> String {
        switch code {
        case 0: return "晴"
        case 1: return "晴间多云"
        case 2: return "多云"
        case 3: return "阴"
        case 45, 48: return "雾"
        case 51, 53, 55: return "毛毛雨"
        case 56, 57: return "冻毛毛雨"
        case 61: return "小雨"
        case 63: return "中雨"
        case 65: return "大雨"
        case 66, 67: return "冻雨"
        case 71: return "小雪"
        case 73: return "中雪"
        case 75: return "大雪"
        case 77: return "雪粒"
        case 80: return "小阵雨"
        case 81: return "阵雨"
        case 82: return "暴雨"
        case 85: return "小阵雪"
        case 86: return "阵雪"
        case 95: return "雷阵雨"
        case 96, 99: return "雷阵雨伴冰雹"
        default: return "未知"
        }
    }

    static func symbol(_ code: Int, isDay: Bool) -> String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57: return "cloud.sleet.fill"
        case 61: return "cloud.rain.fill"
        case 63: return "cloud.rain.fill"
        case 65: return "cloud.heavyrain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80: return isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill"
        case 81: return "cloud.rain.fill"
        case 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95: return "cloud.bolt.rain.fill"
        case 96, 99: return "cloud.hail.fill"
        default: return "cloud.fill"
        }
    }

    /// 原版几何天气图标资源名（Assets.xcassets 里的 imageset 名）
    static func iconName(_ code: Int, isDay: Bool) -> String {
        switch code {
        case 0: return isDay ? "weather_clear_day" : "weather_clear_night"
        case 1, 2: return isDay ? "weather_partly_cloudy_day" : "weather_partly_cloudy_night"
        case 3: return "weather_cloudy"
        case 45, 48: return "weather_fog"
        case 51, 53, 55: return "weather_rain"
        case 56, 57: return "weather_sleet"
        case 61, 63, 65: return "weather_rain"
        case 66, 67: return "weather_sleet"
        case 71, 73, 75, 77: return "weather_snow"
        case 80, 81, 82: return "weather_rain"
        case 85, 86: return "weather_snow"
        case 95: return "weather_thunderstorm"
        case 96, 99: return "weather_hail"
        default: return "weather_cloudy"
        }
    }

    /// 动画帧序列（原版帧动画：base + _1/_2/_3 中实际存在的帧）
    static func iconFrames(_ code: Int, isDay: Bool) -> [String] {
        let base = iconName(code, isDay: isDay)
        let frameCounts: [String: Int] = [
            "weather_clear_day": 3, "weather_cloudy": 3, "weather_hail": 4,
            "weather_haze": 4, "weather_partly_cloudy_day": 4, "weather_partly_cloudy_night": 3,
            "weather_rain": 4, "weather_sleet": 4, "weather_snow": 4,
            "weather_thunder": 3, "weather_thunderstorm": 4,
        ]
        let n = frameCounts[base] ?? 1
        if n <= 1 { return [base] }
        return (0..<n).map { $0 == 0 ? base : "\(base)_\($0)" }
    }

    /// 背景渐变色（顶部色，底部色），按天气与昼夜取
    static func gradient(_ code: Int, isDay: Bool) -> (top: String, bottom: String) {
        if !isDay { return ("#1B2A4A", "#0B1026") }
        switch code {
        case 0, 1: return ("#3D7BDB", "#7FB2F0")
        case 2, 3: return ("#5B7A9E", "#93A9C4")
        case 45, 48: return ("#6E7F8D", "#A7B4BC")
        case 51, 53, 55, 61, 63, 65, 66, 67, 80, 81, 82: return ("#44586E", "#7A8CA3")
        case 71, 73, 75, 77, 85, 86: return ("#7E97B5", "#C3D3E6")
        case 95, 96, 99: return ("#3A4460", "#6B7590")
        default: return ("#3D7BDB", "#7FB2F0")
        }
    }
}
