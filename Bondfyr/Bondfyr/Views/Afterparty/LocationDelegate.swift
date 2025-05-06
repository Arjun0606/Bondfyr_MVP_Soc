import Foundation
import CoreLocation

class LocationDelegate: NSObject, CLLocationManagerDelegate {
    private let onUpdate: (CLLocation?) -> Void

    init(onUpdate: @escaping (CLLocation?) -> Void) {
        self.onUpdate = onUpdate
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        onUpdate(locations.first)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onUpdate(nil)
    }
} 