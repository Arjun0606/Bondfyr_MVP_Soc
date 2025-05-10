import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import SwiftUI

@MainActor
class AfterpartyManager: NSObject, ObservableObject {
    static let shared = AfterpartyManager()
    private let db = Firestore.firestore()
    
    @Published var nearbyAfterparties: [Afterparty] = []
    @Published var userAfterparties: [Afterparty] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var locationManager: CLLocationManager?
    private var currentLocation: CLLocationCoordinate2D?
    private var afterpartyListeners: [ListenerRegistration] = []
    
    private override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.startUpdatingLocation()
    }
    
    func updateLocation(_ coordinate: CLLocationCoordinate2D) {
        currentLocation = coordinate
        Task {
            await fetchNearbyAfterparties()
        }
    }
    
    func createAfterparty(
        hostHandle: String,
        coordinate: CLLocationCoordinate2D,
        radius: Double,
        startTime: Date,
        endTime: Date,
        city: String,
        locationName: String,
        description: String,
        address: String,
        googleMapsLink: String,
        vibeTag: String
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AfterpartyError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let afterparty = Afterparty(
            userId: userId,
            hostHandle: hostHandle,
            coordinate: coordinate,
            radius: radius,
            startTime: startTime,
            endTime: endTime,
            city: city,
            locationName: locationName,
            description: description,
            address: address,
            googleMapsLink: googleMapsLink,
            vibeTag: vibeTag
        )
        
        let data = try Firestore.Encoder().encode(afterparty)
        try await db.collection("afterparties").document(afterparty.id).setData(data)
        
        // Fetch afterparties again to update the UI
        await fetchNearbyAfterparties()
    }
    
    func fetchNearbyAfterparties() async {
        guard let location = currentLocation else { 
            print("No current location available")
            return 
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let currentCity = UserDefaults.standard.string(forKey: "selectedCity") ?? "Unknown"
            print("Fetching afterparties for city: \(currentCity)")
            
            // First just get all afterparties for the city
            let snapshot = try await db.collection("afterparties")
                .whereField("city", isEqualTo: currentCity)
                .getDocuments()
            
            print("Found \(snapshot.documents.count) afterparties in \(currentCity)")
            
            let afterparties = try snapshot.documents.compactMap { doc -> Afterparty? in
                print("Processing document: \(doc.documentID)")
                let data = doc.data()
                print("Document data: \(data)")
                
                // Add document ID to data for decoding
                var docData = data
                docData["id"] = doc.documentID
                
                // Check if the afterparty is still active
                if let endTime = (data["endTime"] as? Timestamp)?.dateValue(),
                   endTime < Date() {
                    print("Skipping expired afterparty")
                    return nil
                }
                
                let afterparty = try Firestore.Decoder().decode(Afterparty.self, from: docData)
                
                // Get locations
                let partyLocation = CLLocation(latitude: afterparty.coordinate.latitude, 
                                             longitude: afterparty.coordinate.longitude)
                let userLocation = CLLocation(latitude: location.latitude, 
                                            longitude: location.longitude)
                
                // Calculate distance
                let distanceInMeters = userLocation.distance(from: partyLocation)
                let radiusInMeters = afterparty.radius // radius is already in meters
                
                print("Afterparty distance: \(distanceInMeters)m, radius: \(radiusInMeters)m")
                
                // Include if within radius
                if distanceInMeters <= radiusInMeters {
                    print("Afterparty is within radius")
                    return afterparty
                } else {
                    print("Afterparty is outside radius")
                    return nil
                }
            }
            
            print("Filtered to \(afterparties.count) nearby afterparties")
            
            await MainActor.run {
                self.nearbyAfterparties = afterparties
            }
        } catch {
            print("Error fetching afterparties: \(error)")
            self.error = error
        }
    }
    
    func joinAfterparty(_ afterparty: Afterparty) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        try await db.collection("afterparties").document(afterparty.id).updateData([
            "pendingRequests": FieldValue.arrayUnion([userId])
        ])
    }
    
    func approveRequest(afterpartyId: String, userId: String) async throws {
        try await db.collection("afterparties").document(afterpartyId).updateData([
            "pendingRequests": FieldValue.arrayRemove([userId]),
            "activeUsers": FieldValue.arrayUnion([userId])
        ])
    }
    
    func denyRequest(afterpartyId: String, userId: String) async throws {
        try await db.collection("afterparties").document(afterpartyId).updateData([
            "pendingRequests": FieldValue.arrayRemove([userId])
        ])
    }
    
    func leaveAfterparty(_ afterparty: Afterparty) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        try await db.collection("afterparties").document(afterparty.id).updateData([
            "activeUsers": FieldValue.arrayRemove([userId])
        ])
    }
    
    func deleteAfterparty(_ afterparty: Afterparty) async throws {
        guard let userId = Auth.auth().currentUser?.uid,
              afterparty.userId == userId else { return }
        
        try await db.collection("afterparties").document(afterparty.id).delete()
    }
    
    deinit {
        afterpartyListeners.forEach { $0.remove() }
    }
}

// Add CLLocationManagerDelegate conformance
extension AfterpartyManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last?.coordinate else { return }
        print("📍 Location updated: \(location.latitude), \(location.longitude)")
        currentLocation = location
        Task {
            await fetchNearbyAfterparties()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
    }
} 