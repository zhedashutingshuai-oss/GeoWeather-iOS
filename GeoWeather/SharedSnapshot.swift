// SharedSnapshot.swift — 主 App 与小组件共享的天气快照（经 App Group 的 UserDefaults 传递）
// 本文件同时编入 App 与 Widget 两个 target。
import Foundation

struct SharedSnapshot: Codable {
    var cityName: String
    var latitude: Double
    var longitude: Double
    var temperature: Double
    var feelsLike: Double
    var humidity: Int
    var code: Int
    var isDay: Bool
    var high: Double
    var low: Double
    var updatedAt: Date

    static func make(from f: ForecastResponse, city: City) -> SharedSnapshot {
        SharedSnapshot(
            cityName: city.name,
            latitude: city.latitude,
            longitude: city.longitude,
            temperature: f.current.temperature_2m,
            feelsLike: f.current.apparent_temperature,
            humidity: f.current.relative_humidity_2m,
            code: f.current.weather_code,
            isDay: f.current.is_day == 1,
            high: f.daily.temperature_2m_max.first ?? f.current.temperature_2m,
            low: f.daily.temperature_2m_min.first ?? f.current.temperature_2m,
            updatedAt: Date()
        )
    }
}

enum SharedSnapshotStore {
    static let suiteName = "group.com.zhedashutingshuai.geoweather"
    static let key = "weatherSnapshot"

    static func save(_ snapshot: SharedSnapshot) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> SharedSnapshot? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SharedSnapshot.self, from: data)
    }
}
