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
            
        let now = Date()
        let calendar = Calendar.current
        
        // Only consider a party "active" if it's currently happening or starts within 2 hours
        return snapshot.documents.contains { doc in
            let data = doc.data()
            guard let startTime = (data["startTime"] as? Timestamp)?.dateValue(),
                  let endTime = (data["endTime"] as? Timestamp)?.dateValue() else {
                return false
            }
            
            // Party is active if:
            // 1. It's currently happening (between start and end time)
            // 2. It starts within the next 2 hours
            let twoHoursFromNow = calendar.date(byAdding: .hour, value: 2, to: now) ?? now
            
            let isCurrentlyHappening = now >= startTime && now <= endTime
            let startsWithinTwoHours = startTime > now && startTime <= twoHoursFromNow
            
            return isCurrentlyHappening || startsWithinTwoHours
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
        legalDisclaimerAccepted: Bool = false,
        
        // TESTFLIGHT: Payment details
        venmoHandle: String? = nil
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
            legalDisclaimerAccepted: legalDisclaimerAccepted,
            
            // TESTFLIGHT: Payment details
            venmoHandle: venmoHandle
        )
        
        let data = try Firestore.Encoder().encode(afterparty)
        try await db.collection("afterparties").document(afterparty.id).setData(data)
        
        // Fetch afterparties again to update the UI
        await fetchNearbyAfterparties()
    }
    
    func fetchNearbyAfterparties() async {
        guard let location = currentLocation else { 
            
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let currentCity = UserDefaults.standard.string(forKey: "selectedCity") ?? "Unknown"
            
            
            // First just get all afterparties for the city
            let snapshot = try await db.collection("afterparties")
                .whereField("city", isEqualTo: currentCity)
                .getDocuments()
            
            
            
            let afterparties = try snapshot.documents.compactMap { doc -> Afterparty? in
                
                let data = doc.data()
                
                
                // Add document ID to data for decoding
                var docData = data
                docData["id"] = doc.documentID
                
                // Check if the afterparty is still active
                if let endTime = (data["endTime"] as? Timestamp)?.dateValue(),
                   endTime < Date() {
                    
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
                
                
                
                // Include if within radius
                if distanceInMeters <= radiusInMeters {
                    
                    return afterparty
                } else {
                    
                    return nil
                }
            }
            
            
            
            await MainActor.run {
                self.nearbyAfterparties = afterparties
            }
        } catch {
            
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
    
    /// TESTFLIGHT VERSION: Request free access (no payment)
    /// TODO: Replace with paid access after validation
    func requestFreeAccess(
        to afterparty: Afterparty,
        userHandle: String,
        userName: String
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AfterpartyError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Check if user already requested or is already going
        if afterparty.activeUsers.contains(userId) {
            throw NSError(domain: "AfterpartyError", code: 409, userInfo: [NSLocalizedDescriptionKey: "You're already going to this afterparty"])
        }
        
        if afterparty.guestRequests.contains(where: { $0.userId == userId }) {
            throw NSError(domain: "AfterpartyError", code: 409, userInfo: [NSLocalizedDescriptionKey: "You've already requested to join this afterparty"])
        }
        
        // Create a guest request (for TestFlight - host still needs to approve)
        let guestRequest = GuestRequest(
            userId: userId,
            userName: userName,
            userHandle: userHandle,
            introMessage: "", // Empty intro for legacy TestFlight flow
            requestedAt: Date(),
            paymentStatus: .paid // Mark as "paid" since it's free for TestFlight
        )
        
        // Update Firestore
        try await db.collection("afterparties").document(afterparty.id).updateData([
            "guestRequests": FieldValue.arrayUnion([try Firestore.Encoder().encode(guestRequest)])
        ])
        
        
    }
    
    /// Submit guest request with intro message (NEW FLOW)
    func submitGuestRequest(afterpartyId: String, guestRequest: GuestRequest) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AfterpartyError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Check if user already requested or is already going
        let doc = try await db.collection("afterparties").document(afterpartyId).getDocument()
        guard let data = doc.data(),
              let afterparty = try? Firestore.Decoder().decode(Afterparty.self, from: data) else {
            throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Afterparty not found"])
        }
        
        if afterparty.activeUsers.contains(userId) {
            throw NSError(domain: "AfterpartyError", code: 409, userInfo: [NSLocalizedDescriptionKey: "You're already going to this afterparty"])
        }
        
        if afterparty.guestRequests.contains(where: { $0.userId == userId }) {
            throw NSError(domain: "AfterpartyError", code: 409, userInfo: [NSLocalizedDescriptionKey: "You've already requested to join this afterparty"])
        }
        
        // Add request to Firestore
        try await db.collection("afterparties").document(afterpartyId).updateData([
            "guestRequests": FieldValue.arrayUnion([try Firestore.Encoder().encode(guestRequest)])
        ])
        
        // Get party details and notify host of new request
        let partyDoc = try await db.collection("afterparties").document(afterpartyId).getDocument()
        if let data = partyDoc.data(),
           let afterparty = try? Firestore.Decoder().decode(Afterparty.self, from: data) {
            NotificationManager.shared.notifyHostOfGuestRequest(
                partyId: afterpartyId,
                partyTitle: afterparty.title,
                guestName: guestRequest.userHandle
            )
        }
        
        
    }
    
    /// Approve guest request (Host action)
    func approveGuestRequest(afterpartyId: String, guestRequestId: String) async throws {
        let doc = try await db.collection("afterparties").document(afterpartyId).getDocument()
        guard let data = doc.data(),
              let afterparty = try? Firestore.Decoder().decode(Afterparty.self, from: data) else {
            throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Afterparty not found"])
        }
        
        // Find and update the guest request
        if let index = afterparty.guestRequests.firstIndex(where: { $0.id == guestRequestId }) {
            let originalRequest = afterparty.guestRequests[index]
            let updatedRequest = GuestRequest(
                id: originalRequest.id,
                userId: originalRequest.userId,
                userName: originalRequest.userName,
                userHandle: originalRequest.userHandle,
                introMessage: originalRequest.introMessage,
                requestedAt: originalRequest.requestedAt,
                paymentStatus: .pending,
                approvalStatus: .approved,
                paypalOrderId: originalRequest.paypalOrderId,
                paidAt: originalRequest.paidAt,
                refundedAt: originalRequest.refundedAt,
                approvedAt: Date()
            )
            
            var updatedRequests = afterparty.guestRequests
            updatedRequests[index] = updatedRequest
            
            // Update Firestore
            try await db.collection("afterparties").document(afterpartyId).updateData([
                "guestRequests": try updatedRequests.map { try Firestore.Encoder().encode($0) }
            ])
            
            // Send approval notification to guest
            NotificationManager.shared.notifyGuestOfApproval(
                partyId: afterpartyId,
                partyTitle: afterparty.title,
                hostName: afterparty.hostHandle
            )
            
            
        }
    }
    
    /// Deny guest request (Host action)
    func denyGuestRequest(afterpartyId: String, guestRequestId: String) async throws {
        let doc = try await db.collection("afterparties").document(afterpartyId).getDocument()
        guard let data = doc.data(),
              let afterparty = try? Firestore.Decoder().decode(Afterparty.self, from: data) else {
            throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Afterparty not found"])
        }
        
        // Find the guest request before removing it (for notification)
        if afterparty.guestRequests.contains(where: { $0.id == guestRequestId }) {
            // Send denial notification to guest
            NotificationManager.shared.notifyGuestOfDenial(
                partyId: afterpartyId,
                partyTitle: afterparty.title,
                hostName: afterparty.hostHandle
            )
        }
        
        // Remove the guest request
        var updatedRequests = afterparty.guestRequests
        updatedRequests.removeAll { $0.id == guestRequestId }
        
        // Update Firestore
        try await db.collection("afterparties").document(afterpartyId).updateData([
            "guestRequests": try updatedRequests.map { try Firestore.Encoder().encode($0) }
        ])
        
        
    }
    
    /// Track estimated transaction value for analytics (TestFlight version)
    func trackEstimatedTransaction(afterpartyId: String, estimatedValue: Double) async {
        let analyticsData: [String: Any] = [
            "afterpartyId": afterpartyId,
            "estimatedValue": estimatedValue,
            "timestamp": Timestamp(date: Date()),
            "type": "testflight_estimated_transaction",
            "platform": "ios"
        ]
        
        do {
            try await db.collection("analytics").addDocument(data: analyticsData)
            
        } catch {
            
        }
    }
    
    /// Get estimated total transaction volume (for TestFlight analytics)
    func getEstimatedRevenue() async throws -> (totalVolume: Double, commission: Double, transactionCount: Int) {
        let snapshot = try await db.collection("analytics")
            .whereField("type", isEqualTo: "testflight_estimated_transaction")
            .getDocuments()
        
        let totalVolume = snapshot.documents.reduce(0.0) { total, doc in
            let value = doc.data()["estimatedValue"] as? Double ?? 0.0
            return total + value
        }
        
        let commission = totalVolume * 0.20 // 20% commission
        let transactionCount = snapshot.documents.count
        
        return (totalVolume, commission, transactionCount)
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
        
        let afterparties = snapshot.documents.compactMap { doc -> Afterparty? in
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
    
    /// Get parties hosted by a specific user
    func getHostParties(hostId: String) async throws -> [Afterparty] {
        // Simplified query - just filter by userId (no orderBy to avoid index requirement)
        let snapshot = try await db.collection("afterparties")
            .whereField("userId", isEqualTo: hostId)
            .getDocuments()
        
        let afterparties = snapshot.documents.compactMap { doc -> Afterparty? in
            var docData = doc.data()
            docData["id"] = doc.documentID
            return try? Firestore.Decoder().decode(Afterparty.self, from: docData)
        }
        
        // Filter out expired parties (older than 9 hours from creation) and sort in memory
        let now = Date()
        let activeParties = afterparties.filter { afterparty in
            let nineHoursAfterCreation = Calendar.current.date(byAdding: .hour, value: 9, to: afterparty.createdAt) ?? Date()
            return nineHoursAfterCreation > now
        }
        
        // Sort by creation date in memory (most recent first)
        return activeParties.sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Filter afterparties for marketplace discovery
    func getMarketplaceAfterparties(
        priceRange: ClosedRange<Double>? = nil,
        vibes: [String]? = nil,
        timeFilter: TimeFilter = .all
    ) async throws -> [Afterparty] {
        // Simplified query - just get public parties (no compound queries to avoid index requirement)
        let snapshot = try await db.collection("afterparties")
            .whereField("visibility", isEqualTo: PartyVisibility.publicFeed.rawValue)
            .getDocuments()
        
        var afterparties = snapshot.documents.compactMap { doc -> Afterparty? in
            var docData = doc.data()
            docData["id"] = doc.documentID
            
            // Skip expired afterparties
            if let endTime = (docData["endTime"] as? Timestamp)?.dateValue(),
               endTime < Date() {
                return nil
            }
            
            return try? Firestore.Decoder().decode(Afterparty.self, from: docData)
        }
        
        // Apply price range filter in memory
        if let priceRange = priceRange {
            afterparties = afterparties.filter { afterparty in
                afterparty.ticketPrice >= priceRange.lowerBound &&
                afterparty.ticketPrice <= priceRange.upperBound
            }
        }
        
        // Apply vibe filters in memory
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
        
        currentLocation = location
        Task {
            await fetchNearbyAfterparties()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
    }
} 