import Foundation
import Combine

final class WeatherStore: ObservableObject {
    @Published var cities: [City] {
        didSet { persist() }
    }
    @Published var selectedID: String

    private static let storageKey = "savedCities.v1"

    init() {
        // 先算到本地变量再赋给属性：init 里在所有属性就绪前不能回读 self 的属性（编译器铁律）
        let initialCities: [City]
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([City].self, from: data),
           !saved.isEmpty {
            initialCities = saved
        } else {
            initialCities = [.beijing]
        }
        cities = initialCities
        selectedID = initialCities[0].id
    }

    var selectedCity: City {
        cities.first { $0.id == selectedID } ?? cities[0]
    }

    func addCity(_ city: City) {
        if !cities.contains(city) {
            cities.append(city)
        }
        selectedID = city.id
    }

    func setLocatedCity(_ city: City) {
        if let idx = cities.firstIndex(where: { $0.id == selectedID }) {
            // 定位城市替换当前选中项的位置，避免列表无限增长
            if cities[idx].id != city.id {
                cities[idx] = city
            }
        } else {
            cities.insert(city, at: 0)
        }
        selectedID = city.id
    }

    func removeCity(_ city: City) {
        guard cities.count > 1 else { return }
        cities.removeAll { $0.id == city.id }
        if selectedID == city.id {
            selectedID = cities[0].id
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(cities) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
