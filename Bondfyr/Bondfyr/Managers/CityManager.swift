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
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private let locationManager = CLLocationManager()
    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    // Major Indian cities with nightlife
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
        setupInitialData()
    }
    
    private func setupInitialData() {
        // Load saved city and country from UserDefaults
        selectedCity = defaults.string(forKey: "selectedCity")
        selectedCountry = defaults.string(forKey: "selectedCountry")
    }

    // MARK: - City Selection Methods
    func setCity(_ city: String) {
        selectedCity = city
        defaults.set(city, forKey: "selectedCity")
    }
    
    func setCountry(_ country: String) {
        selectedCountry = country
        defaults.set(country, forKey: "selectedCountry")
    }
    
    func clearSelection() {
        selectedCity = nil
        selectedCountry = nil
        defaults.removeObject(forKey: "selectedCity")
        defaults.removeObject(forKey: "selectedCountry")
    }

    func fetchCities() {
        isLoading = true
        
        // First populate with scraped venue data
        Task {
            await scrapeVenueData()
            
            // Then fetch from Firestore
            db.collection("venues").getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    print("Error fetching cities: \(error.localizedDescription)")
                    return
                }
                
                if let docs = snapshot?.documents {
                    let firestoreCities = Set(docs.compactMap { $0.data()["city"] as? String })
                    let allCities = Set(self.cities).union(firestoreCities)
                    self.cities = Array(allCities).sorted()
                }
            }
        }
    }
    
    private func scrapeVenueData() async {
        // Implement venue scraping for each major city
        for (city, _) in majorCities {
            do {
                let venues = try await scrapeVenuesForCity(city)
                await saveVenuesToFirestore(venues, city: city)
            } catch {
                print("Error scraping venues for \(city): \(error.localizedDescription)")
            }
        }
    }
    
    private func scrapeVenuesForCity(_ city: String) async throws -> [(name: String, type: String, location: CLLocationCoordinate2D)] {
        // Example implementation - replace with actual scraping logic
        switch city {
        case "Mumbai":
            return [
                ("Trilogy", "Club", CLLocationCoordinate2D(latitude: 18.9548, longitude: 72.8224)),
                ("Toto's Garage", "Bar", CLLocationCoordinate2D(latitude: 19.0635, longitude: 72.8351)),
                ("antiSOCIAL", "Club", CLLocationCoordinate2D(latitude: 19.1307, longitude: 72.8324))
            ]
        case "Pune":
            return [
                ("High Spirits", "Bar", CLLocationCoordinate2D(latitude: 18.5423, longitude: 73.9092)),
                ("Mi-A-Mi", "Club", CLLocationCoordinate2D(latitude: 18.5528, longitude: 73.9179)),
                ("Area 51", "Club", CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567))
            ]
        // Add more cities with their popular venues
        default:
            return []
        }
    }
    
    private func saveVenuesToFirestore(_ venues: [(name: String, type: String, location: CLLocationCoordinate2D)], city: String) async {
        let batch = db.batch()
        
        for venue in venues {
            let docRef = db.collection("venues").document()
            let data: [String: Any] = [
                "name": venue.name,
                "genre": venue.type,
                "city": city,
                "location": GeoPoint(latitude: venue.location.latitude, longitude: venue.location.longitude),
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]
            batch.setData(data, forDocument: docRef, merge: true)
        }
        
        do {
            try await batch.commit()
            print("✅ Saved \(venues.count) venues for \(city)")
        } catch {
            print("❌ Error saving venues: \(error.localizedDescription)")
        }
    }

    func detectUserCity(completion: @escaping (String?) -> Void) {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        
        // First try to get location
        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestLocation()
            
            self.$userLocation
                .compactMap { $0 }
                .first()
                .sink { [weak self] location in
                    self?.findNearestCity(to: location, completion: completion)
                }
                .store(in: &cancellables)
        } else {
            completion(nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.first
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
        userLocation = nil
    }

    private func findNearestCity(to location: CLLocation, completion: @escaping (String?) -> Void) {
        // First check against major cities
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
            completion(city)
            return
        }
        
        // If no major city found, check Firestore venues
        db.collection("venues").getDocuments { snapshot, error in
            guard let docs = snapshot?.documents else {
                completion(nil)
                return
            }
            
            var cityCounts: [String: Int] = [:]
            for doc in docs {
                if let lat = doc.data()["latitude"] as? Double,
                   let lon = doc.data()["longitude"] as? Double,
                   let city = doc.data()["city"] as? String {
                    let venueLoc = CLLocation(latitude: lat, longitude: lon)
                    if location.distance(from: venueLoc) < 25000 { // Within 25km
                        cityCounts[city, default: 0] += 1
                    }
                }
            }
            
            let bestMatch = cityCounts.max { $0.value < $1.value }?.key
            completion(bestMatch)
        }
    }

    func updateCity(_ city: String) {
        setCity(city)
    }
    
    func updateLocation(_ newLocation: CLLocation) {
        location = newLocation
    }
} 