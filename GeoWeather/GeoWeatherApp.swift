import SwiftUI

@main
struct GeoWeatherApp: App {
    @StateObject private var store = WeatherStore()
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(locationManager)
        }
    }
}
