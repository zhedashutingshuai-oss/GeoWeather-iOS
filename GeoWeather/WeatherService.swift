import Foundation

enum WeatherService {
    static func fetchForecast(for city: City) async throws -> ForecastResponse {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: "\(city.latitude)"),
            .init(name: "longitude", value: "\(city.longitude)"),
            .init(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,surface_pressure_msl,wind_speed_10m,wind_direction_10m,wind_gusts_10m"),
            .init(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability"),
            .init(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max"),
            .init(name: "timezone", value: "auto"),
            .init(name: "forecast_days", value: "15"),
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        return try JSONDecoder().decode(ForecastResponse.self, from: data)
    }

    static func fetchAirQuality(for city: City) async throws -> AirQualityResponse {
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
