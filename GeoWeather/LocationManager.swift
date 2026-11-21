import Foundation
import Combine
import CoreLocation

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var locatedCity: City?
    @Published var denied = false
    /// 最近一次定位（工具页坐标/指南针用）
    @Published var currentLocation: CLLocation?
    /// 罗盘朝向（度，0 = 北）
    @Published var heading: Double = 0

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var didGeocode = false

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

    /// 工具页用：连续定位（高精度）＋罗盘朝向
    func startLiveUpdates() {
        guard manager.authorizationStatus == .authorizedWhenInUse
                || manager.authorizationStatus == .authorizedAlways else {
            requestLocation()
            return
        }
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stopLiveUpdates() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let h = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        DispatchQueue.main.async { self.heading = h }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async { self.currentLocation = location }
        // 逆地理只做第一次，后续连续定位不再重复解析城市
        guard !didGeocode else { return }
        didGeocode = true
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
