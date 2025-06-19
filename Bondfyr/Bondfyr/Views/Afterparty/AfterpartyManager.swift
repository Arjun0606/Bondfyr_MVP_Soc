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
    
    func hasActiveAfterparty() async throws -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        
        let snapshot = try await db.collection("afterparties")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
            
        // Check if any of the user's afterparties are still active
        return snapshot.documents.contains { doc in
            guard let endTime = (doc.data()["endTime"] as? Timestamp)?.dateValue() else {
                return false
            }
            return endTime > Date()
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
        vibeTag: String,
        
        // New marketplace parameters
        title: String,
        ticketPrice: Double,
        coverPhotoURL: String? = nil,
        maxGuestCount: Int,
        visibility: PartyVisibility = .publicFeed,
        approvalType: ApprovalType = .manual,
        ageRestriction: Int? = nil,
        maxMaleRatio: Double = 1.0,
        legalDisclaimerAccepted: Bool = false
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AfterpartyError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Check if user already has an active afterparty
        if try await hasActiveAfterparty() {
            throw NSError(
                domain: "AfterpartyError",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "You can only host one afterparty at a time. Please wait for your current afterparty to end or cancel it before creating a new one."]
            )
        }
        
        // Set creation time and calculate end time (9 hours from creation)
        let creationTime = Date()
        let nineHoursFromNow = Calendar.current.date(byAdding: .hour, value: 9, to: creationTime) ?? Date()
        
        let afterparty = Afterparty(
            userId: userId,
            hostHandle: hostHandle,
            coordinate: coordinate,
            radius: radius,
            startTime: startTime,
            endTime: nineHoursFromNow,
            city: city,
            locationName: locationName,
            description: description,
            address: address,
            googleMapsLink: googleMapsLink,
            vibeTag: vibeTag,
            createdAt: creationTime,
            
            // New marketplace fields
            title: title,
            ticketPrice: ticketPrice,
            coverPhotoURL: coverPhotoURL,
            maxGuestCount: maxGuestCount,
            visibility: visibility,
            approvalType: approvalType,
            ageRestriction: ageRestriction,
            maxMaleRatio: maxMaleRatio,
            legalDisclaimerAccepted: legalDisclaimerAccepted
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
    
    // MARK: - New Paid Marketplace Methods
    
    /// Request paid access to an afterparty
    func requestPaidAccess(
        to afterparty: Afterparty,
        userHandle: String,
        userName: String
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AfterpartyError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Check if party is sold out
        if afterparty.isSoldOut {
            throw NSError(domain: "AfterpartyError", code: 403, userInfo: [NSLocalizedDescriptionKey: "This party is sold out!"])
        }
        
        // Check if user already requested access
        if afterparty.guestRequests.contains(where: { $0.userId == userId }) {
            throw NSError(domain: "AfterpartyError", code: 409, userInfo: [NSLocalizedDescriptionKey: "You already requested access to this party"])
        }
        
        // Create guest request with payment processing
        let success = try await PaymentService.shared.requestAfterpartyAccess(
            afterparty: afterparty,
            userId: userId,
            userName: userName,
            userHandle: userHandle
        )
        
        if success {
            // Add to Firebase with pending payment status
            let guestRequest = GuestRequest(
                userId: userId,
                userName: userName,
                userHandle: userHandle,
                paymentStatus: .pending,
                stripePaymentIntentId: "pi_placeholder_\(UUID().uuidString)"
            )
            
            // Update Firestore
            var updatedRequests = afterparty.guestRequests
            updatedRequests.append(guestRequest)
            
            try await db.collection("afterparties").document(afterparty.id).updateData([
                "guestRequests": updatedRequests.map { try Firestore.Encoder().encode($0) }
            ])
        }
    }
    
    /// Approve a paid guest request (host action)
    func approvePaidGuest(afterpartyId: String, guestRequestId: String) async throws {
        // In real implementation, this would:
        // 1. Verify payment was successful
        // 2. Move guest from pending to confirmed
        // 3. Update host earnings
        // 4. Send confirmation notification
        
        try await db.collection("afterparties").document(afterpartyId).updateData([
            "pendingRequests": FieldValue.arrayRemove([guestRequestId]),
            "activeUsers": FieldValue.arrayUnion([guestRequestId])
        ])
    }
    
    /// Get host earnings dashboard
    func getHostEarnings(for hostId: String) async throws -> HostEarnings {
        let snapshot = try await db.collection("afterparties")
            .whereField("userId", isEqualTo: hostId)
            .getDocuments()
        
        let afterparties = try snapshot.documents.compactMap { doc -> Afterparty? in
            var docData = doc.data()
            docData["id"] = doc.documentID
            return try? Firestore.Decoder().decode(Afterparty.self, from: docData)
        }
        
        // Calculate earnings
        let totalEarnings = afterparties.reduce(0) { $0 + $1.hostEarnings }
        let totalGuests = afterparties.reduce(0) { $0 + $1.confirmedGuestsCount }
        let averagePartySize = afterparties.isEmpty ? 0 : Double(totalGuests) / Double(afterparties.count)
        
        // Create transactions (placeholder)
        let transactions: [Transaction] = []
        
        return HostEarnings(
            totalEarnings: totalEarnings,
            totalAfterparties: afterparties.count,
            totalGuests: totalGuests,
            averagePartySize: averagePartySize,
            thisMonth: totalEarnings * 0.3, // Placeholder
            lastMonth: totalEarnings * 0.2, // Placeholder
            pendingPayouts: totalEarnings * 0.1, // Placeholder
            transactions: transactions
        )
    }
    
    /// Filter afterparties for marketplace discovery
    func getMarketplaceAfterparties(
        priceRange: ClosedRange<Double>? = nil,
        vibes: [String]? = nil,
        timeFilter: TimeFilter = .all
    ) async throws -> [Afterparty] {
        // Base query for public afterparties only
        var query = db.collection("afterparties")
            .whereField("visibility", isEqualTo: PartyVisibility.publicFeed.rawValue)
        
        // Add price filter if specified
        if let priceRange = priceRange {
            query = query
                .whereField("ticketPrice", isGreaterThanOrEqualTo: priceRange.lowerBound)
                .whereField("ticketPrice", isLessThanOrEqualTo: priceRange.upperBound)
        }
        
        let snapshot = try await query.getDocuments()
        
        var afterparties = try snapshot.documents.compactMap { doc -> Afterparty? in
            var docData = doc.data()
            docData["id"] = doc.documentID
            
            // Skip expired afterparties
            if let endTime = (docData["endTime"] as? Timestamp)?.dateValue(),
               endTime < Date() {
                return nil
            }
            
            return try? Firestore.Decoder().decode(Afterparty.self, from: docData)
        }
        
        // Apply client-side filters
        if let vibes = vibes, !vibes.isEmpty {
            afterparties = afterparties.filter { afterparty in
                vibes.allSatisfy { afterparty.vibeTag.contains($0) }
            }
        }
        
        // Apply time filter
        switch timeFilter {
        case .tonight:
            afterparties = afterparties.filter { Calendar.current.isDateInToday($0.startTime) }
        case .upcoming:
            afterparties = afterparties.filter { $0.startTime > Date() }
        case .ongoing:
            afterparties = afterparties.filter { 
                $0.startTime <= Date() && $0.endTime > Date()
            }
        case .all:
            break
        }
        
        // Sort by start time
        return afterparties.sorted { $0.startTime < $1.startTime }
    }
    
    enum TimeFilter {
        case all, tonight, upcoming, ongoing
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
        
        // Delete the afterparty
        try await db.collection("afterparties").document(afterparty.id).delete()
        
        // Update the UI by removing the deleted afterparty
        await MainActor.run {
            self.nearbyAfterparties.removeAll { $0.id == afterparty.id }
        }
    }
    
    func addGuest(afterpartyId: String, guestHandle: String) async throws {
        // First, find the user ID from the handle
        let snapshot = try await db.collection("users")
            .whereField("handle", isEqualTo: guestHandle.lowercased())
            .limit(to: 1)
            .getDocuments()
        
        guard let userDoc = snapshot.documents.first,
              let userId = userDoc.data()["uid"] as? String else {
            throw NSError(domain: "AfterpartyError", 
                         code: 404, 
                         userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        // Add user directly to activeUsers
        try await db.collection("afterparties").document(afterpartyId).updateData([
            "activeUsers": FieldValue.arrayUnion([userId])
        ])
    }
    
    func removeGuest(afterpartyId: String, userId: String) async throws {
        try await db.collection("afterparties").document(afterpartyId).updateData([
            "activeUsers": FieldValue.arrayRemove([userId])
        ])
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