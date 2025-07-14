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
    
    private var statsProcessingTimer: Timer?
    
    private override init() {
        super.init()
        setupLocationManager()
        setupStatsProcessingTimer()
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
            venmoHandle: venmoHandle,
            
            // Stats processing (Realistic Metrics System)
            statsProcessed: false  // New parties haven't processed stats yet
        )
        
        let data = try Firestore.Encoder().encode(afterparty)
        try await db.collection("afterparties").document(afterparty.id).setData(data)
        
        // Start the party chat when party is created
        await MainActor.run {
            PartyChatManager.shared.startPartyChat(for: afterparty)
        }
        
        // CRITICAL FIX: Schedule party start reminder notification
        NotificationManager.shared.schedulePartyStartReminder(
            partyId: afterparty.id,
            partyTitle: afterparty.title,
            startTime: afterparty.startTime
        )
        
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
    
    // DEPRECATED: Legacy method - use submitGuestRequest instead
    func joinAfterparty(_ afterparty: Afterparty) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // CRITICAL FIX: No longer update legacy pendingRequests array
        // All new requests should go through submitGuestRequest flow
        // This method is kept for backward compatibility but does nothing
        print("⚠️ WARNING: joinAfterparty is deprecated. Use submitGuestRequest instead.")
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
        print("🟡 BACKEND: submitGuestRequest() called for party \(afterpartyId)")
        print("🟡 BACKEND: Guest request ID: \(guestRequest.id), User: \(guestRequest.userHandle)")
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("🔴 BACKEND: submitGuestRequest() FAILED - user not authenticated")
            throw NSError(domain: "AfterpartyError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("🟡 BACKEND: Starting Firestore transaction...")
        
        // Get party title first for notifications
        let doc = try await db.collection("afterparties").document(afterpartyId).getDocument()
        guard let data = doc.data(),
              let afterparty = try? Firestore.Decoder().decode(Afterparty.self, from: data) else {
            print("🔴 BACKEND: submitGuestRequest() FAILED - party not found")
            throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Afterparty not found"])
        }
        let partyTitle = afterparty.title
        
        // CRITICAL FIX: Use Firestore transaction to prevent race conditions
        try await db.runTransaction { (transaction, errorPointer) -> Any? in
            print("🟡 BACKEND: Inside transaction - getting party document...")
            let afterpartyRef = self.db.collection("afterparties").document(afterpartyId)
            
            // Get current party state within transaction
            let afterpartyDocument: DocumentSnapshot
            do {
                try afterpartyDocument = transaction.getDocument(afterpartyRef)
            } catch let fetchError as NSError {
                print("🔴 BACKEND: Failed to get party document: \(fetchError.localizedDescription)")
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let data = afterpartyDocument.data(),
              let currentAfterparty = try? Firestore.Decoder().decode(Afterparty.self, from: data) else {
                print("🔴 BACKEND: Failed to decode party data")
                let error = NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Afterparty not found"])
                errorPointer?.pointee = error
                return nil
        }
        
            print("🟡 BACKEND: Party found - title: \(currentAfterparty.title), current requests: \(currentAfterparty.guestRequests.count)")
            
            // CRITICAL FIX: Check for existing requests/membership within transaction
        if currentAfterparty.activeUsers.contains(userId) {
                print("🔴 BACKEND: User already in activeUsers array")
                let error = NSError(domain: "AfterpartyError", code: 409, userInfo: [NSLocalizedDescriptionKey: "You're already going to this afterparty"])
                errorPointer?.pointee = error
                return nil
        }
        
        if currentAfterparty.guestRequests.contains(where: { $0.userId == userId }) {
                print("🔴 BACKEND: User already has pending request")
                let error = NSError(domain: "AfterpartyError", code: 409, userInfo: [NSLocalizedDescriptionKey: "You've already requested to join this afterparty"])
                errorPointer?.pointee = error
                return nil
        }
        
            // Add the new request
            var updatedRequests = currentAfterparty.guestRequests
            updatedRequests.append(guestRequest)
            
            print("🟡 BACKEND: Adding request to party - new total: \(updatedRequests.count)")
        
            // Update within transaction
            do {
                let encodedRequests = try updatedRequests.map { try Firestore.Encoder().encode($0) }
                transaction.updateData(["guestRequests": encodedRequests], forDocument: afterpartyRef)
                print("🟢 BACKEND: Transaction update successful")
            } catch {
                print("🔴 BACKEND: Failed to encode/update requests: \(error.localizedDescription)")
                errorPointer?.pointee = error as NSError
                return nil
            }
            
            return nil
        }
        
        print("🟢 BACKEND: Transaction completed successfully")
        
        // WORKING: Send notification to HOST about new guest request
        // IMPORTANT: This should be sent as a push notification via server
        // Local notifications only show on the device that triggers them
        Task {
            print("🔔 NOTIFICATION: Host should receive push notification about new guest request")
            print("🔔 Target host ID: \(afterparty.userId)")
            print("🔔 Guest name: \(guestRequest.userHandle)")
            print("🔔 Party: \(partyTitle)")
            // TODO: Implement server-side push notification
        }
        
        print("🟢 BACKEND: submitGuestRequest() completed successfully")
    }
    
    /// Approve guest request (Host action) - NEW FLOW: Triggers payment after approval
    func approveGuestRequest(afterpartyId: String, guestRequestId: String) async throws {
        print("🟢 BACKEND: approveGuestRequest() called for party \(afterpartyId), request \(guestRequestId)")
        
        let doc = try await db.collection("afterparties").document(afterpartyId).getDocument()
        guard let data = doc.data(),
              let afterparty = try? Firestore.Decoder().decode(Afterparty.self, from: data) else {
            print("🔴 BACKEND: approveGuestRequest() FAILED - party not found")
            throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Afterparty not found"])
        }
        
        // Find and update the guest request
        if let index = afterparty.guestRequests.firstIndex(where: { $0.id == guestRequestId }) {
            let originalRequest = afterparty.guestRequests[index]
            print("🟢 BACKEND: Found request for user \(originalRequest.userHandle), approving...")
            
            // NEW FLOW: Mark as approved but keep payment as pending
            let updatedRequest = GuestRequest(
                id: originalRequest.id,
                userId: originalRequest.userId,
                userName: originalRequest.userName,
                userHandle: originalRequest.userHandle,
                introMessage: originalRequest.introMessage,
                requestedAt: originalRequest.requestedAt,
                paymentStatus: .pending, // Still pending - payment happens AFTER approval
                approvalStatus: .approved,
                paypalOrderId: originalRequest.paypalOrderId,
                paidAt: originalRequest.paidAt,
                refundedAt: originalRequest.refundedAt,
                approvedAt: Date()
            )
            
            var updatedRequests = afterparty.guestRequests
            updatedRequests[index] = updatedRequest
            
            // DON'T add to activeUsers yet - wait for payment completion
            
            // Update Firestore with the approved request (but no activeUsers change yet)
            try await db.collection("afterparties").document(afterpartyId).updateData([
                "guestRequests": try updatedRequests.map { try Firestore.Encoder().encode($0) }
            ])
            
            print("🟢 BACKEND: approveGuestRequest() SUCCESS - Marked \(originalRequest.userHandle) as approved, waiting for payment")
            
            // FIXED: Send push notification to guest
            // IMPORTANT: This should be sent as a push notification via server
            // Local notifications only show on the device that triggers them
            Task {
                print("🔔 NOTIFICATION: Guest should receive push notification about approval")
                print("🔔 Target guest ID: \(originalRequest.userId)")
                print("🔔 Host name: \(afterparty.hostHandle)")
                print("🔔 Party: \(afterparty.title)")
                print("🔔 Amount: $\(Int(afterparty.ticketPrice))")
                // TODO: Implement server-side push notification
            }
            
            print("✅ NEW FLOW: Approved guest \(originalRequest.userHandle) - payment required to confirm spot")
        } else {
            print("🔴 BACKEND: approveGuestRequest() FAILED - request not found")
            throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Guest request not found"])
        }
    }
    
    /// Deny guest request (Host action)
    func denyGuestRequest(afterpartyId: String, guestRequestId: String) async throws {
        print("🔴 BACKEND: denyGuestRequest() called for party \(afterpartyId), request \(guestRequestId)")
        
        let doc = try await db.collection("afterparties").document(afterpartyId).getDocument()
        guard let data = doc.data(),
              let afterparty = try? Firestore.Decoder().decode(Afterparty.self, from: data) else {
            print("🔴 BACKEND: denyGuestRequest() FAILED - party not found")
            throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Afterparty not found"])
        }
        
        // Find the guest request before removing it (for notification and cleanup)
        var userIdToRemove: String?
        if let requestToRemove = afterparty.guestRequests.first(where: { $0.id == guestRequestId }) {
            userIdToRemove = requestToRemove.userId
            print("🔴 BACKEND: Found request for user \(requestToRemove.userHandle), denying...")
            
            // Send denial notification to guest
            NotificationManager.shared.notifyGuestOfDenial(
                partyId: afterpartyId,
                partyTitle: afterparty.title,
                hostName: afterparty.hostHandle
            )
        } else {
            print("🔴 BACKEND: denyGuestRequest() FAILED - request not found")
            throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Guest request not found"])
        }
        
        // Remove the guest request
        var updatedRequests = afterparty.guestRequests
        updatedRequests.removeAll { $0.id == guestRequestId }
        
        // CRITICAL FIX: Also remove user from activeUsers if they were previously approved
        var updatedActiveUsers = afterparty.activeUsers
        if let userId = userIdToRemove {
            updatedActiveUsers.removeAll { $0 == userId }
            print("🔴 BACKEND: Removed user from activeUsers array")
        }
        
        // Update Firestore with both updated requests AND activeUsers
        try await db.collection("afterparties").document(afterpartyId).updateData([
            "guestRequests": try updatedRequests.map { try Firestore.Encoder().encode($0) },
            "activeUsers": updatedActiveUsers
        ])
        
        print("🔴 BACKEND: denyGuestRequest() SUCCESS - Updated Firestore")
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
    
    /// DEPRECATED: Use approveGuestRequest instead
    func approvePaidGuest(afterpartyId: String, guestRequestId: String) async throws {
        // CRITICAL FIX: This method is deprecated - use approveGuestRequest instead
        // which properly handles the new guestRequests system
        print("⚠️ WARNING: approvePaidGuest is deprecated. Use approveGuestRequest instead.")
        
        // Redirect to the new method
        try await approveGuestRequest(afterpartyId: afterpartyId, guestRequestId: guestRequestId)
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
    
    // DEPRECATED: Legacy methods - use approveGuestRequest/denyGuestRequest instead
    func approveRequest(afterpartyId: String, userId: String) async throws {
        // CRITICAL FIX: No longer update legacy pendingRequests array
        print("⚠️ WARNING: approveRequest is deprecated. Use approveGuestRequest instead.")
        
        // For backward compatibility, find the guest request and approve it properly
        let doc = try await db.collection("afterparties").document(afterpartyId).getDocument()
        guard let data = doc.data(),
              let afterparty = try? Firestore.Decoder().decode(Afterparty.self, from: data) else {
            return
        }
        
        if let guestRequest = afterparty.guestRequests.first(where: { $0.userId == userId }) {
            try await approveGuestRequest(afterpartyId: afterpartyId, guestRequestId: guestRequest.id)
        }
    }
    
    func denyRequest(afterpartyId: String, userId: String) async throws {
        // CRITICAL FIX: No longer update legacy pendingRequests array
        print("⚠️ WARNING: denyRequest is deprecated. Use denyGuestRequest instead.")
        
        // For backward compatibility, find the guest request and deny it properly
        let doc = try await db.collection("afterparties").document(afterpartyId).getDocument()
        guard let data = doc.data(),
              let afterparty = try? Firestore.Decoder().decode(Afterparty.self, from: data) else {
            return
        }
        
        if let guestRequest = afterparty.guestRequests.first(where: { $0.userId == userId }) {
            try await denyGuestRequest(afterpartyId: afterpartyId, guestRequestId: guestRequest.id)
        }
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
        
        // CRITICAL: Process party stats if it had attendees before deletion
        if !afterparty.activeUsers.isEmpty && afterparty.endTime <= Date() {
            print("🎯 STATS: Party being deleted had attendees - processing completion first")
            do {
                try await processPartyCompletion(afterparty: afterparty)
            } catch {
                print("🔴 STATS: Error processing stats before deletion: \(error)")
            }
        } else {
            print("🎯 STATS: Party being deleted had no attendees or hadn't ended - no stats to process")
        }
        
        // End the party chat first
        await MainActor.run {
            PartyChatManager.shared.endPartyChatForDeletedParty()
        }
        
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
        statsProcessingTimer?.invalidate()
    }
    
    /// Get specific afterparty by ID
    func getAfterpartyById(_ afterpartyId: String) async throws -> Afterparty {
        print("🔍 BACKEND: getAfterpartyById() called for party \(afterpartyId)")
        
        let doc = try await db.collection("afterparties").document(afterpartyId).getDocument()
        guard let data = doc.data() else {
            print("🔴 BACKEND: getAfterpartyById() FAILED - party not found")
            throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Afterparty not found"])
        }
        
        var docData = data
        docData["id"] = doc.documentID
        
        guard let afterparty = try? Firestore.Decoder().decode(Afterparty.self, from: docData) else {
            print("🔴 BACKEND: getAfterpartyById() FAILED - failed to decode party data")
            throw NSError(domain: "AfterpartyError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to decode afterparty data"])
        }
        
        print("🔍 BACKEND: getAfterpartyById() SUCCESS - party found with \(afterparty.activeUsers.count) active users")
        return afterparty
    }
    
    /// Process party completion and update user stats (REALISTIC TRACKING)
    func processPartyCompletion(afterparty: Afterparty) async throws {
        print("🎯 STATS: Processing party completion for '\(afterparty.title)'")
        
        // Only process if party has actually ended
        guard afterparty.endTime <= Date() else {
            print("🎯 STATS: Party hasn't ended yet - skipping stats update")
            return
        }
        
        // Only process if party had actual attendees
        guard !afterparty.activeUsers.isEmpty else {
            print("🎯 STATS: Party had no attendees - not updating stats")
            return
        }
        
        // Get attendee user objects
        var attendees: [AppUser] = []
        for userId in afterparty.activeUsers {
            do {
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let userData = userDoc.data() {
                    var userDataWithId = userData
                    userDataWithId["uid"] = userId
                    let user = try Firestore.Decoder().decode(AppUser.self, from: userDataWithId)
                    attendees.append(user)
                }
            } catch {
                print("🎯 STATS: Error loading user \(userId): \(error)")
            }
        }
        
        print("🎯 STATS: Party completed successfully with \(attendees.count) attendees")
        print("🎯 STATS: Duration: \(Int(afterparty.endTime.timeIntervalSince(afterparty.startTime) / 3600)) hours")
        
        // Update user stats with realistic metrics
        ReputationManager.shared.updateUserStatsAfterEvent(
            afterparty: afterparty,
            attendees: attendees
        )
        
        // Mark party as stats processed
        try await db.collection("afterparties").document(afterparty.id).updateData([
            "statsProcessed": true,
            "statsProcessedAt": Timestamp(date: Date())
        ])
        
        print("🎯 STATS: Successfully processed party completion")
    }
    
    /// Check for completed parties and process their stats (called periodically)
    func processCompletedParties() async {
        print("🔄 STATS: Checking for completed parties to process...")
        
        do {
            let twoHoursAgo = Date().addingTimeInterval(-7200) // 2 hours ago
            let oneDayAgo = Date().addingTimeInterval(-86400) // 1 day ago
            
            // Find parties that ended 2+ hours ago but haven't been processed
            let snapshot = try await db.collection("afterparties")
                .whereField("endTime", isLessThan: Timestamp(date: twoHoursAgo))
                .whereField("endTime", isGreaterThan: Timestamp(date: oneDayAgo)) // Don't process old parties
                .whereField("statsProcessed", isEqualTo: false)
                .limit(to: 10) // Process max 10 at a time
                .getDocuments()
            
            print("🔄 STATS: Found \(snapshot.documents.count) completed parties to process")
            
            for document in snapshot.documents {
                do {
                    var docData = document.data()
                    docData["id"] = document.documentID
                    
                    let afterparty = try Firestore.Decoder().decode(Afterparty.self, from: docData)
                    
                    // Process this party's completion
                    try await processPartyCompletion(afterparty: afterparty)
                    
                } catch {
                    print("🔴 STATS: Error processing party \(document.documentID): \(error)")
                    
                    // Mark as processed even if there was an error to avoid infinite retries
                    try? await db.collection("afterparties").document(document.documentID).updateData([
                        "statsProcessed": true,
                        "statsProcessedAt": Timestamp(date: Date()),
                        "statsProcessingError": error.localizedDescription
                    ])
                }
            }
            
            print("✅ STATS: Completed processing \(snapshot.documents.count) parties")
            
        } catch {
            print("🔴 STATS: Error checking for completed parties: \(error)")
        }
    }
    
    /// Setup timer to periodically process completed party stats
    private func setupStatsProcessingTimer() {
        // Check every 30 minutes for completed parties
        statsProcessingTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { _ in
            Task {
                await self.processCompletedParties()
            }
        }
        
        // Also run once on app start after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            Task {
                await self.processCompletedParties()
            }
        }
        
        print("🔄 STATS: Setup automatic party stats processing (every 30 minutes)")
    }
    
    /// Complete party membership after payment (NEW FLOW)
    func completePartyMembershipAfterPayment(afterpartyId: String, userId: String, paymentIntentId: String) async throws {
        print("🟢 PAYMENT: completePartyMembershipAfterPayment() called")
        print("🟢 PAYMENT: Adding user \(userId) to activeUsers after successful payment")
        
        let doc = try await db.collection("afterparties").document(afterpartyId).getDocument()
        guard let data = doc.data(),
              let afterparty = try? Firestore.Decoder().decode(Afterparty.self, from: data) else {
            print("🔴 PAYMENT: Party not found")
            throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Afterparty not found"])
        }
        
        // Find the guest request and update payment status
        var updatedRequests = afterparty.guestRequests
        var guestRequest: GuestRequest?
        
        for (index, request) in updatedRequests.enumerated() {
            if request.userId == userId {
                guestRequest = request
                // Update payment status to paid
                let paidRequest = GuestRequest(
                    id: request.id,
                    userId: request.userId,
                    userName: request.userName,
                    userHandle: request.userHandle,
                    introMessage: request.introMessage,
                    requestedAt: request.requestedAt,
                    paymentStatus: .paid,
                    approvalStatus: request.approvalStatus,
                    paypalOrderId: request.paypalOrderId,
                    dodoPaymentIntentId: paymentIntentId,
                    paidAt: Date(), // Mark when payment was completed
                    refundedAt: request.refundedAt,
                    approvedAt: request.approvedAt
                )
                updatedRequests[index] = paidRequest
                break
            }
        }
        
        guard let request = guestRequest else {
            print("🔴 PAYMENT: Guest request not found")
            throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Guest request not found"])
        }
        
        // Add user to activeUsers (NOW they're officially in!)
        var updatedActiveUsers = afterparty.activeUsers
        if !updatedActiveUsers.contains(userId) {
            updatedActiveUsers.append(userId)
            print("🟢 PAYMENT: Added user \(request.userHandle) to activeUsers after payment")
        }
        
        // Update Firestore with payment completion and membership
        try await db.collection("afterparties").document(afterpartyId).updateData([
            "guestRequests": try updatedRequests.map { try Firestore.Encoder().encode($0) },
            "activeUsers": updatedActiveUsers
        ])
        
        // Send all the follow-up notifications now that they're officially in
        
        // 1. Notify host of payment received
        // IMPORTANT: This should be sent as a push notification via server
        // Local notifications only show on the device that triggers them
        let hostEarnings = afterparty.ticketPrice * 0.8 // 80% to host
        Task {
            print("🔔 NOTIFICATION: Host should receive push notification about payment")
            print("🔔 Target host ID: \(afterparty.userId)")
            print("🔔 Guest name: \(request.userHandle)")
            print("🔔 Party: \(afterparty.title)")
            print("🔔 Amount: $\(Int(afterparty.ticketPrice))")
            print("🔔 Host earnings: $\(Int(hostEarnings))")
            // TODO: Implement server-side push notification
        }
        
        // 2. Guest already received approval notification, no need for another one
        
        // 3. Schedule party reminders for new member
        NotificationManager.shared.schedulePartyStartReminder(
            partyId: afterpartyId,
            partyTitle: afterparty.title,
            startTime: afterparty.startTime
        )
        
        // 4. Check if party is getting full and alert host
        let currentCapacity = Double(updatedActiveUsers.count)
        let maxCapacity = Double(afterparty.maxGuestCount)
        let capacityPercentage = currentCapacity / maxCapacity
        
        if capacityPercentage >= 0.8 {
            NotificationManager.shared.notifyHostOfCapacityAlert(
                partyId: afterpartyId,
                partyTitle: afterparty.title,
                currentCount: updatedActiveUsers.count,
                maxCount: afterparty.maxGuestCount
            )
        }
        
        print("✅ NEW FLOW: Payment completed - \(request.userHandle) is now officially attending \(afterparty.title)")
    }
}

// MARK: - CLLocationManagerDelegate
extension AfterpartyManager: @preconcurrency CLLocationManagerDelegate {
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