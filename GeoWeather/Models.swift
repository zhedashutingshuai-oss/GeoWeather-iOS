import Foundation

struct City: Identifiable, Codable, Equatable {
    let name: String
    let country: String?
    let admin1: String?
    let latitude: Double
    let longitude: Double

    var id: String { "\(latitude),\(longitude)" }

    var subtitle: String {
        [admin1, country]
            .compactMap { $0 }
            .filter { !$0.isEmpty && $0 != name }
            .joined(separator: " · ")
    }

    static let beijing = City(name: "北京", country: "中国", admin1: "北京",
                              latitude: 39.9042, longitude: 116.4074)
}

struct ForecastResponse: Decodable {
    let timezone: String
    let current: CurrentWeather
    let hourly: HourlyWeather
    let daily: DailyWeather
}

struct CurrentWeather: Decodable {
    let time: String
    let temperature_2m: Double
    let relative_humidity_2m: Int
    let apparent_temperature: Double
    let is_day: Int
    let weather_code: Int
    let surface_pressure_msl: Double
    let wind_speed_10m: Double
    let wind_direction_10m: Int
    let wind_gusts_10m: Double
}

struct HourlyWeather: Decodable {
    let time: [String]
    let temperature_2m: [Double]
    let weather_code: [Int]
    let precipitation_probability: [Int?]?
}

struct DailyWeather: Decodable {
    let time: [String]
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let sunrise: [String]
    let sunset: [String]
    let uv_index_max: [Double]
    let precipitation_probability_max: [Int?]?
}

struct AirQualityResponse: Decodable {
    let current: AirQualityCurrent
}

struct AirQualityCurrent: Decodable {
    let us_aqi: Double?
    let pm2_5: Double?
    let pm10: Double?
}

struct GeocodingResponse: Decodable {
    let results: [GeocodingResult]?
}

struct GeocodingResult: Decodable {
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?
}
