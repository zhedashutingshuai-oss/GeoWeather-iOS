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

struct ForecastResponse: Codable {
    let timezone: String
    let current: CurrentWeather
    let hourly: HourlyWeather
    let daily: DailyWeather
    let minutely_15: MinutelyWeather?
}

/// 逐 15 分钟数据（降水预报条用）
struct MinutelyWeather: Codable {
    let time: [String]
    let precipitation: [Double]
}

struct CurrentWeather: Codable {
    let time: String
    let temperature_2m: Double
    let relative_humidity_2m: Int
    let apparent_temperature: Double
    let is_day: Int
    let weather_code: Int
    let pressure_msl: Double
    let cloud_cover: Int
    let precipitation: Double
    let wind_speed_10m: Double
    let wind_direction_10m: Int
    let wind_gusts_10m: Double
}

struct HourlyWeather: Codable {
    let time: [String]
    let temperature_2m: [Double]
    let weather_code: [Int]
    let precipitation_probability: [Int?]?
    let precipitation: [Double]
    let visibility: [Double]
    let dew_point_2m: [Double]
}

struct DailyWeather: Codable {
    let time: [String]
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let sunrise: [String]
    let sunset: [String]
    let uv_index_max: [Double]
    let precipitation_probability_max: [Int?]?
    let precipitation_sum: [Double]
    let wind_speed_10m_max: [Double]
}

/// Open-Meteo 出错时返回的 JSON：{"error":true,"reason":"..."}
struct APIErrorResponse: Decodable {
    let error: Bool
    let reason: String
}

struct AirQualityResponse: Codable {
    let current: AirQualityCurrent
}

struct AirQualityCurrent: Codable {
    let us_aqi: Double?
    let pm2_5: Double?
    let pm10: Double?
    let carbon_monoxide: Double?
    let nitrogen_dioxide: Double?
    let sulphur_dioxide: Double?
    let ozone: Double?
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
