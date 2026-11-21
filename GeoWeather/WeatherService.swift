import Foundation

enum WeatherService {
    /// 带重试的请求：网络层错误（TLS 瞬断、超时等）自动重试 3 次，间隔递增；
    /// API 业务错误（domain == "OpenMeteo"，如参数非法）与任务取消不重试，直接抛出。
    private static func withRetry<T>(_ operation: () async throws -> T) async throws -> T {
        let delays: [UInt64] = [0, 1_200_000_000, 2_500_000_000]
        var lastError: Error = URLError(.unknown)
        for delay in delays {
            if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
            do {
                return try await operation()
            } catch {
                if (error as NSError).domain == "OpenMeteo" { throw error }
                if error is CancellationError { throw error }
                lastError = error
            }
        }
        throw lastError
    }

    static func fetchForecast(for city: City) async throws -> ForecastResponse {
        try await withRetry { try await fetchForecastOnce(for: city) }
    }

    static func fetchAirQuality(for city: City) async throws -> AirQualityResponse {
        try await withRetry { try await fetchAirQualityOnce(for: city) }
    }

    private static func fetchForecastOnce(for city: City) async throws -> ForecastResponse {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: "\(city.latitude)"),
            .init(name: "longitude", value: "\(city.longitude)"),
            .init(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,pressure_msl,cloud_cover,precipitation,wind_speed_10m,wind_direction_10m,wind_gusts_10m"),
            .init(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability,precipitation,visibility,dew_point_2m"),
            .init(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max,precipitation_sum,wind_speed_10m_max"),
            .init(name: "timezone", value: "auto"),
            .init(name: "forecast_days", value: "15"),
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        // 接口出错时先把官方 reason 抛出来，方便定位（截图可见）
        if let apiErr = try? JSONDecoder().decode(APIErrorResponse.self, from: data), apiErr.error {
            throw NSError(domain: "OpenMeteo", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: apiErr.reason])
        }
        return try JSONDecoder().decode(ForecastResponse.self, from: data)
    }

    private static func fetchAirQualityOnce(for city: City) async throws -> AirQualityResponse {
        var comps = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!
        comps.queryItems = [
            .init(name: "latitude", value: "\(city.latitude)"),
            .init(name: "longitude", value: "\(city.longitude)"),
            .init(name: "current", value: "us_aqi,pm2_5,pm10"),
            .init(name: "timezone", value: "auto"),
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        return try JSONDecoder().decode(AirQualityResponse.self, from: data)
    }

    static func searchCities(_ query: String) async throws -> [City] {
        var comps = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        comps.queryItems = [
            .init(name: "name", value: query),
            .init(name: "count", value: "10"),
            .init(name: "language", value: "zh"),
            .init(name: "format", value: "json"),
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let response = try JSONDecoder().decode(GeocodingResponse.self, from: data)
        return (response.results ?? []).map {
            City(name: $0.name, country: $0.country, admin1: $0.admin1,
                 latitude: $0.latitude, longitude: $0.longitude)
        }
    }
}
