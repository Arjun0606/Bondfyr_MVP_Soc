import Foundation
import FirebaseFirestore
import CoreLocation
import Combine
import SwiftUI

class CityManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = CityManager()
    
    // MARK: - Published Properties
    @Published var cities: [String] = []
    @Published var selectedCity: String? = nil
    @Published var selectedCountry: String? = nil
    @Published var userLocation: CLLocation? = nil
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var location: CLLocation?
    @Published var isInSelectedCity: Bool = false
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private let locationManager = CLLocationManager()
    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    // Major Indian cities with nightlife and their boundaries (50km radius)
    private let majorCities = [
        "Mumbai": CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777),
        "Delhi": CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090),
        "Bangalore": CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946),
        "Pune": CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567),
        "Hyderabad": CLLocationCoordinate2D(latitude: 17.3850, longitude: 78.4867),
        "Chennai": CLLocationCoordinate2D(latitude: 13.0827, longitude: 80.2707)
    ]

    private override init() {
        super.init()
        setupLocationManager()
        setupInitialData()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 500 // Update location when user moves 500 meters
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
        
        // Request location permission if not determined
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    private func setupInitialData() {
        // Load saved city from UserDefaults
        if AppStoreDemoManager.shared.isDemoAccount {
            selectedCity = "Austin"
            defaults.set("Austin", forKey: "selectedCity")
        } else {
            selectedCity = defaults.string(forKey: "selectedCity")
        }
        
        // Start monitoring location
        startMonitoringLocation()
    }
    
    func startMonitoringLocation() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // DEMO: Force San Francisco regardless of actual device location
        if AppStoreDemoManager.shared.isDemoAccount {
            selectedCity = "Austin"
            defaults.set("Austin", forKey: "selectedCity")
            userLocation = CLLocation(latitude: 30.2672, longitude: -97.7431)
            location = userLocation
            isInSelectedCity = true
            return
        }
        guard let newLocation = locations.last else { return }
        userLocation = newLocation
        location = newLocation
        
        // Check if we're in the selected city
        if let selectedCity = selectedCity {
            checkIfInCity(selectedCity, userLocation: newLocation)
        } else {
            // If no city is selected, automatically detect and set the city
            detectAndSetCity(for: newLocation)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startMonitoringLocation()
        case .denied, .restricted:
            error = "Location access is required for full app functionality"
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
        self.error = "Failed to get location: \(error.localizedDescription)"
    }
    
    // MARK: - City Detection and Management
    private func detectAndSetCity(for location: CLLocation) {
        var nearestCity: String? = nil
        var shortestDistance = Double.infinity
        
        for (city, coordinate) in majorCities {
            let cityLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = location.distance(from: cityLocation)
            
            if distance < shortestDistance && distance < 50000 { // Within 50km
                shortestDistance = distance
                nearestCity = city
            }
        }
        
        if let city = nearestCity {
            setCity(city)
            checkIfInCity(city, userLocation: location)
        }
    }
    
    private func checkIfInCity(_ city: String, userLocation: CLLocation) {
        guard let cityCoordinate = majorCities[city] else { return }
        
        let cityLocation = CLLocation(latitude: cityCoordinate.latitude, longitude: cityCoordinate.longitude)
        let distance = userLocation.distance(from: cityLocation)
        
        // Update isInSelectedCity based on whether user is within 50km of city center
        isInSelectedCity = distance <= 50000 // 50km radius
    }

    // MARK: - City Selection Methods
    func setCity(_ city: String) {
        selectedCity = city
        defaults.set(city, forKey: "selectedCity")
        
        // Check if user is in this city
        if let userLocation = userLocation {
            checkIfInCity(city, userLocation: userLocation)
        }
    }
    
    func clearSelection() {
        selectedCity = nil
        selectedCountry = nil
        defaults.removeObject(forKey: "selectedCity")
        defaults.removeObject(forKey: "selectedCountry")
        
        // Try to detect city based on current location
        if let location = userLocation {
            detectAndSetCity(for: location)
        }
    }

    // MARK: - Permission Checks
    func canPostInCurrentCity() -> Bool {
        return isInSelectedCity
    }
    
    func canJoinAfterparty() -> Bool {
        return isInSelectedCity
    }
    
    func canUploadPhotos() -> Bool {
        return isInSelectedCity
    }
    
    func canLikeAndClimb() -> Bool {
        return isInSelectedCity
    }
    
    // Everyone can explore cities regardless of location
    func canExploreCity() -> Bool {
        return true
    }
} 