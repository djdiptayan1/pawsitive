import Combine
import CoreLocation
import Foundation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var location: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        print("📍 [LocationManager] Initializing...")
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
        print("📍 [LocationManager] Current authorization status: \(authorizationStatus.rawValue)")
    }

    func requestPermission() {
        print("📍 [LocationManager] Requesting location permission...")
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        print("📍 [LocationManager] Starting location updates...")
        print("   Authorization status: \(authorizationStatus.rawValue)")
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        print("📍 [LocationManager] Stopping location updates...")
        manager.stopUpdatingLocation()
    }

    func locationManager(
        _ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus
    ) {
        print("📍 [LocationManager] Authorization changed: \(status.rawValue)")
        DispatchQueue.main.async {
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                print("✅ [LocationManager] Location authorized! Starting updates...")
                self.startUpdating()
            } else {
                print("⚠️ [LocationManager] Location not authorized: \(status.rawValue)")
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else {
            print("⚠️ [LocationManager] Received empty locations array")
            return
        }
        print(
            "📍 [LocationManager] Location update: \(loc.coordinate.latitude), \(loc.coordinate.longitude)"
        )
        DispatchQueue.main.async {
            self.location = loc.coordinate
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ [LocationManager] Location error: \(error.localizedDescription)")
    }
}
