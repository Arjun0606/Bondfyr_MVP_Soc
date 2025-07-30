import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var currentCity: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // THROTTLING: Prevent excessive geocoding
    private var lastGeocodingTime: Date?
    private var lastGeocodedLocation: CLLocation?
    private let geocodingThrottleInterval: TimeInterval = 60 // Only geocode once per minute
    private let significantLocationChange: CLLocationDistance = 1000 // 1km
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            break // Location access denied
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Only update if accuracy is good enough
        if location.horizontalAccuracy <= 100 {
            self.location = location
            
            // THROTTLED GEOCODING: Only geocode if needed
            let now = Date()
            let shouldGeocode: Bool = {
                // First time geocoding
                guard let lastTime = lastGeocodingTime else { return true }
                
                // More than 60 seconds since last geocoding
                if now.timeIntervalSince(lastTime) > geocodingThrottleInterval {
                    return true
                }
                
                // Location changed significantly (>1km)
                if let lastLocation = lastGeocodedLocation,
                   location.distance(from: lastLocation) > significantLocationChange {
                    return true
                }
                
                return false
            }()
            
            if shouldGeocode {
                lastGeocodingTime = now
                lastGeocodedLocation = location
                
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
                guard let self = self,
                      let placemark = placemarks?.first,
                      let city = placemark.locality else {
                    if let error = error {
                        print("Geocoding error: \(error)")
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.currentCity = city
                    UserDefaults.standard.set(city, forKey: "selectedCity")
                        
                        // OPTIMIZATION: Stop location updates once we have city to save battery and API calls
                        self.locationManager.stopUpdatingLocation()
                    }
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
    }
    
    // MARK: - Public Methods
    
    /// Restart location updates if needed (e.g., user wants to refresh location)
    func refreshLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        locationManager.startUpdatingLocation()
    }
} 