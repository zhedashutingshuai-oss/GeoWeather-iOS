import Foundation

/// 上次成功数据的本地缓存：网络失败时兜底展示，避免整页报错。
enum ForecastCache {
    private static func key(for city: City) -> String { "forecastCache.v1." + city.id }

    static func save(_ f: ForecastResponse, for city: City) {
        if let data = try? JSONEncoder().encode(f) {
            UserDefaults.standard.set(data, forKey: key(for: city))
            UserDefaults.standard.set(Date().timeIntervalSince1970,
                                      forKey: key(for: city) + ".at")
        }
    }

    static func load(for city: City) -> (forecast: ForecastResponse, savedAt: Date)? {
        guard let data = UserDefaults.standard.data(forKey: key(for: city)),
              let f = try? JSONDecoder().decode(ForecastResponse.self, from: data)
        else { return nil }
        let ts = UserDefaults.standard.double(forKey: key(for: city) + ".at")
        return (f, ts > 0 ? Date(timeIntervalSince1970: ts) : Date())
    }
}
