import Foundation
import CoreLocation

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var locatedCity: City?
    @Published var denied = false

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            denied = true
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied
            || manager.authorizationStatus == .restricted {
            denied = true
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let locale = Locale(identifier: "zh_CN")
        geocoder.reverseGeocodeLocation(location, preferredLocale: locale) { [weak self] placemarks, _ in
            let pm = placemarks?.first
            let name = pm?.locality ?? pm?.administrativeArea ?? "当前位置"
            let city = City(name: name,
                            country: pm?.country,
                            admin1: pm?.administrativeArea,
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude)
            DispatchQueue.main.async { self?.locatedCity = city }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 定位失败时静默回退到默认城市
    }
}
