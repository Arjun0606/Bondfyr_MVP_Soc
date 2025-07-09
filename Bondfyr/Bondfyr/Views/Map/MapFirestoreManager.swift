import Foundation
import FirebaseFirestore
import CoreLocation

struct VenueFirestore: Identifiable {
    let id: String
    let name: String
    let city: String
    let coordinate: CLLocationCoordinate2D
    let genre: String
}

struct FootTraffic: Identifiable {
    let id: String // venueId
    let crowdLevel: CrowdLevel
    let currentCrowdEstimate: Int?
    let busynessScore: Double?
    let updatedAt: Date
}

struct VenueWithCrowd: Identifiable {
    let id: String
    let name: String
    let city: String
    let coordinate: CLLocationCoordinate2D
    let genre: String
    let crowdLevel: CrowdLevel
    let currentCrowdEstimate: Int?
    let busynessScore: Double?
    let updatedAt: Date?
    var distance: Double?
}

class MapFirestoreManager: ObservableObject {
    static let shared = MapFirestoreManager()
    private let db = Firestore.firestore()
    
    @Published var venues: [VenueWithCrowd] = []
    private var venueListener: ListenerRegistration?
    private var footTrafficListener: ListenerRegistration?
    
    private init() {}
    
    deinit {
        stopListening()
    }
    
    func startListening() {
        // Listen to venues
        venueListener = db.collection("venues").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let docs = snapshot?.documents else { return }
            let venues = docs.compactMap { doc -> VenueFirestore? in
                let data = doc.data()
                guard let name = data["name"] as? String,
                      let city = data["city"] as? String,
                      let geo = data["location"] as? GeoPoint,
                      let genre = data["genre"] as? String else { return nil }
                let coord = CLLocationCoordinate2D(latitude: geo.latitude, longitude: geo.longitude)
                return VenueFirestore(id: doc.documentID, name: name, city: city, coordinate: coord, genre: genre)
            }
            self.fetchFootTraffic(for: venues)
        }
    }
    
    private func fetchFootTraffic(for venues: [VenueFirestore]) {
        // Listen to footTraffic
        footTrafficListener?.remove()
        footTrafficListener = db.collection("footTraffic").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let docs = snapshot?.documents else { return }
            let traffic = docs.compactMap { doc -> FootTraffic? in
                let data = doc.data()
                guard let crowdStr = data["crowdLevel"] as? String,
                      let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else { return nil }
                let crowdLevel = CrowdLevel(rawValue: crowdStr) ?? .low
                let currentCrowdEstimate = data["currentCrowdEstimate"] as? Int
                let busynessScore = data["busynessScore"] as? Double
                return FootTraffic(id: doc.documentID, crowdLevel: crowdLevel, currentCrowdEstimate: currentCrowdEstimate, busynessScore: busynessScore, updatedAt: updatedAt)
            }
            // Merge venues and traffic
            let userLocation = CityManager.shared.userLocation
            let merged: [VenueWithCrowd] = venues.map { venue in
                let distance = userLocation.map { CLLocation(latitude: venue.coordinate.latitude, longitude: venue.coordinate.longitude).distance(from: $0) }
                if let traffic = traffic.first(where: { $0.id == venue.id }) {
                    return VenueWithCrowd(id: venue.id, name: venue.name, city: venue.city, coordinate: venue.coordinate, genre: venue.genre, crowdLevel: traffic.crowdLevel, currentCrowdEstimate: traffic.currentCrowdEstimate, busynessScore: traffic.busynessScore, updatedAt: traffic.updatedAt, distance: distance)
                } else {
                    return VenueWithCrowd(id: venue.id, name: venue.name, city: venue.city, coordinate: venue.coordinate, genre: venue.genre, crowdLevel: .low, currentCrowdEstimate: nil, busynessScore: nil, updatedAt: nil, distance: distance)
                }
            }
            DispatchQueue.main.async {
                self.venues = merged
            }
        }
    }
    
    func stopListening() {
        venueListener?.remove()
        footTrafficListener?.remove()
        venueListener = nil
        footTrafficListener = nil
    }
    
    func refreshVenues() {
        stopListening()
        startListening()
    }
} 