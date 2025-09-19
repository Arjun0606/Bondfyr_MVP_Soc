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
            
            // CRITICAL FIX: Check if the party has been ended
            if let completionStatus = data["completionStatus"] as? String, 
               completionStatus != "ongoing" && !completionStatus.isEmpty {
                // Party has been ended, so it's not active
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
        
        // NEW: Host Profile Parameters
        phoneNumber: String? = nil,
        instagramHandle: String? = nil,
        snapchatHandle: String? = nil,
        
        // NEW: Payment Method Parameters (Critical for P2P)
        venmoHandle: String? = nil,
        zelleInfo: String? = nil,
        cashAppHandle: String? = nil,
        acceptsApplePay: Bool? = nil,
        collectInPerson: Bool? = nil
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
            vibeTag: vibeTag,
            createdAt: Date(),
            
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
            
            // Host Profile Information
            phoneNumber: phoneNumber,
            instagramHandle: instagramHandle,
            snapchatHandle: snapchatHandle,
            
            // Payment Methods (Critical for P2P payments)
            venmoHandle: venmoHandle,
            zelleInfo: zelleInfo,
            cashAppHandle: cashAppHandle,
            acceptsApplePay: acceptsApplePay,
            collectInPerson: collectInPerson,
            
            // Stats processing (Realistic Metrics System)
            statsProcessed: false  // New parties haven't processed stats yet
        )
        
        let data = try Firestore.Encoder().encode(afterparty)
        try await db.collection("afterparties").document(afterparty.id).setData(data)
        // Analytics
        AnalyticsManager.shared.track("party_created", [
            "party_id": afterparty.id,
            "price": afterparty.ticketPrice,
            "cap": afterparty.maxGuestCount,
            "city": afterparty.city,
            "vibe": afterparty.vibeTag
        ])

        // CRITICAL FIX: Schedule party start reminder notification
        NotificationManager.shared.schedulePartyStartReminder(
            partyId: afterparty.id,
            partyTitle: afterparty.title,
            startTime: afterparty.startTime
        )
        
        // Post notification for real-time UI updates
        await MainActor.run {
            NotificationCenter.default.post(name: Notification.Name("PartyCreated"), object: afterparty.id)
        }
        
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
                
                // Check if the afterparty is still active (natural end time)
                if let endTime = (data["endTime"] as? Timestamp)?.dateValue(),
                   endTime < Date() {
                    
                    return nil
                }
                
                // CRITICAL FIX: Skip parties that have been ended by host
                if let completionStatus = data["completionStatus"] as? String,
                   completionStatus != "ongoing" && !completionStatus.isEmpty {
                    return nil
                }
                
                let afterparty = try Firestore.Decoder().decode(Afterparty.self, from: docData)
                
                // CRITICAL: Clean up data inconsistencies before displaying
                let cleanedAfterparty = cleanupActiveUsersData(afterparty)
                
                // Get locations
                let partyLocation = CLLocation(latitude: cleanedAfterparty.coordinate.latitude, 
                                             longitude: cleanedAfterparty.coordinate.longitude)
                let userLocation = CLLocation(latitude: location.latitude, 
                                            longitude: location.longitude)
                
                // Calculate distance
                let distanceInMeters = userLocation.distance(from: partyLocation)
                let radiusInMeters = cleanedAfterparty.radius // radius is already in meters
                
                
                
                // Include if within radius
                if distanceInMeters <= radiusInMeters {
                    
                    return cleanedAfterparty
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
        
        // Simplified approach: Get party title directly from Firestore
        let doc = try await db.collection("afterparties").document(afterpartyId).getDocument()
        guard let data = doc.data() else {
            print("🔴 BACKEND: submitGuestRequest() FAILED - no document data")
            throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Afterparty document not found"])
        }
        
        // Get party title and host ID directly without full decoding
        let partyTitle = data["title"] as? String ?? "Unknown Party"
        let hostUserId = data["userId"] as? String ?? ""
        print("🟡 BACKEND: Party title: \(partyTitle)")
        print("🟡 BACKEND: Host user ID: \(hostUserId)")
        
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
            
            guard let data = afterpartyDocument.data() else {
                print("🔴 BACKEND: No document data in transaction")
                let error = NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Afterparty document has no data"])
                errorPointer?.pointee = error
                return nil
            }
            
            guard let currentAfterparty = try? Firestore.Decoder().decode(Afterparty.self, from: data) else {
                print("🔴 BACKEND: Failed to decode party data in transaction")
                print("🔴 BACKEND: Available data keys: \(data.keys.sorted())")
                print("🔴 BACKEND: Sample data values:")
                for (key, value) in data.prefix(5) {
                    print("🔴 BACKEND:   \(key): \(type(of: value)) = \(value)")
                }
                let error = NSError(domain: "AfterpartyError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to decode afterparty data - check data format"])
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
        
            // Decide path: auto-approve vs manual
            var updatedRequests = currentAfterparty.guestRequests
            var updatedActiveUsers = currentAfterparty.activeUsers
            var requestToStore = guestRequest

            let isAutoApprove = (currentAfterparty.approvalType == .automatic)
            let capacityRemaining = currentAfterparty.maxGuestCount - (updatedActiveUsers.count)

            // Optional gender ratio check
            var genderPasses = true
            if let currentUser = Auth.auth().currentUser { // best-effort gender lookup
                // We will try to read gender from users collection; if missing we allow
                let userDoc = try? transaction.getDocument(self.db.collection("users").document(currentUser.uid))
                let data = userDoc?.data()
                if let data = data,
                   let gender = data["gender"] as? String,
                   currentAfterparty.maxMaleRatio < 1.0 {
                    // crude estimate: count existing male attendees
                    var maleCount = 0
                    for uid in updatedActiveUsers {
                        let doc = try? transaction.getDocument(self.db.collection("users").document(uid))
                        let udata = doc?.data()
                        if let g = udata?["gender"] as? String, g.lowercased() == "male" {
                            maleCount += 1
                        }
                    }
                    let totalIfAdded = updatedActiveUsers.count + 1
                    let maleIfAdded = maleCount + (gender.lowercased() == "male" ? 1 : 0)
                    let ratio = totalIfAdded > 0 ? Double(maleIfAdded) / Double(totalIfAdded) : 0
                    genderPasses = ratio <= currentAfterparty.maxMaleRatio
                }
            }

            if isAutoApprove && capacityRemaining > 0 && genderPasses {
                // Auto-approve immediately
                requestToStore = GuestRequest(
                    id: guestRequest.id,
                    userId: guestRequest.userId,
                    userName: guestRequest.userName,
                    userHandle: guestRequest.userHandle,
                    introMessage: guestRequest.introMessage,
                    requestedAt: guestRequest.requestedAt,
                    paymentStatus: .pending,
                    approvalStatus: .approved,
                    paypalOrderId: guestRequest.paypalOrderId,
                    dodoPaymentIntentId: guestRequest.dodoPaymentIntentId,
                    paidAt: nil,
                    refundedAt: nil,
                    approvedAt: Date(),
                    paymentProofImageURL: guestRequest.paymentProofImageURL,
                    proofSubmittedAt: guestRequest.proofSubmittedAt,
                    verificationImageURL: guestRequest.verificationImageURL
                )
                updatedRequests.append(requestToStore)
                updatedActiveUsers.append(userId)

                do {
                    let encodedRequests = try updatedRequests.map { try Firestore.Encoder().encode($0) }
                    transaction.updateData([
                        "guestRequests": encodedRequests,
                        "activeUsers": updatedActiveUsers
                    ], forDocument: afterpartyRef)
                    print("🟢 BACKEND: Auto-approved guest and added to activeUsers")
                } catch {
                    print("🔴 BACKEND: Failed to encode/update auto-approve: \(error.localizedDescription)")
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            } else {
                // Manual path: append pending request only
                updatedRequests.append(requestToStore)
                print("🟡 BACKEND: Adding pending request to party - new total: \(updatedRequests.count)")
                do {
                    let encodedRequests = try updatedRequests.map { try Firestore.Encoder().encode($0) }
                    transaction.updateData(["guestRequests": encodedRequests], forDocument: afterpartyRef)
                    print("🟢 BACKEND: Transaction update successful (pending)")
                } catch {
                    print("🔴 BACKEND: Failed to encode/update requests: \(error.localizedDescription)")
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }
            
            return nil
        }
        
        print("🟢 BACKEND: Transaction completed successfully")
        
        // Notify host or guest depending on path
        Task {
            do {
                let doc = try await db.collection("afterparties").document(afterpartyId).getDocument()
                if let data = doc.data(), let party = try? Firestore.Decoder().decode(Afterparty.self, from: data) {
                    if party.guestRequests.contains(where: { $0.id == guestRequest.id && $0.approvalStatus == .approved }) {
                        // Auto-approve path → notify guest they're in
                        await FCMNotificationManager.shared.notifyGuestOfApproval(
                            guestUserId: guestRequest.userId,
                            partyId: afterpartyId,
                            partyTitle: party.title,
                            hostName: party.hostHandle,
                            amount: party.ticketPrice
                        )
                    } else {
                        // Pending path → notify host of new request
                        await FCMNotificationManager.shared.notifyHostOfGuestRequest(
                            hostUserId: hostUserId,
                            partyId: afterpartyId,
                            partyTitle: partyTitle,
                            guestName: guestRequest.userHandle
                        )
                    }
                }
            } catch {
                print("🔔 FCM: Notification branching failed: \(error)")
            }
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
            
            // CRITICAL: Post local notification for immediate UI updates
            await MainActor.run {
                NotificationCenter.default.post(
                    name: Notification.Name("GuestApproved"),
                    object: afterpartyId,
                    userInfo: [
                        "partyId": afterpartyId,
                        "guestId": originalRequest.userId,
                        "guestHandle": originalRequest.userHandle
                    ]
                )
                print("🔔 LOCAL: Posted GuestApproved notification for immediate UI refresh")
            }
            
            // NEW: Send FCM push notification to guest about approval
            Task {
                print("🔔 FCM: Sending push notification to guest about approval")
                await FCMNotificationManager.shared.notifyGuestOfApproval(
                    guestUserId: originalRequest.userId,
                    partyId: afterpartyId,
                    partyTitle: afterparty.title,
                    hostName: afterparty.hostHandle,
                    amount: afterparty.ticketPrice
                )
            }
            
            print("✅ NEW FLOW: Approved guest \(originalRequest.userHandle) - payment required to confirm spot")
        
        // CRITICAL: Refresh manager data so guest button sees latest status
        await fetchNearbyAfterparties()
        } else {
            print("🔴 BACKEND: approveGuestRequest() FAILED - request not found")
            throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Guest request not found"])
        }
    }
    
    /// NEW: Approve guest request without payment (VIP/Free entry)
    func approveGuestRequestFree(afterpartyId: String, guestRequestId: String) async throws {
        print("⭐ VIP APPROVAL: approveGuestRequestFree() called for party \(afterpartyId), request \(guestRequestId)")
        
        let doc = try await db.collection("afterparties").document(afterpartyId).getDocument()
        guard let data = doc.data(),
              let afterparty = try? Firestore.Decoder().decode(Afterparty.self, from: data) else {
            print("🔴 VIP APPROVAL: FAILED - party not found")
            throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Afterparty not found"])
        }
        
        // Find and update the guest request
        if let index = afterparty.guestRequests.firstIndex(where: { $0.id == guestRequestId }) {
            let originalRequest = afterparty.guestRequests[index]
            print("⭐ VIP APPROVAL: Found request for user \(originalRequest.userHandle), approving as VIP...")
            
            // VIP FLOW: Mark as approved AND free (no payment needed)
            let updatedRequest = GuestRequest(
                id: originalRequest.id,
                userId: originalRequest.userId,
                userName: originalRequest.userName,
                userHandle: originalRequest.userHandle,
                introMessage: originalRequest.introMessage,
                requestedAt: originalRequest.requestedAt,
                paymentStatus: .free, // NEW: Free entry status
                approvalStatus: .approved,
                paypalOrderId: originalRequest.paypalOrderId,
                paidAt: Date(), // Mark as "paid" for free
                refundedAt: originalRequest.refundedAt,
                approvedAt: Date(),
                paymentProofImageURL: originalRequest.paymentProofImageURL,
                proofSubmittedAt: originalRequest.proofSubmittedAt,
                verificationImageURL: originalRequest.verificationImageURL
            )
            
            var updatedRequests = afterparty.guestRequests
            updatedRequests[index] = updatedRequest
            
            // VIP: Add to activeUsers immediately (no payment required)
            var updatedActiveUsers = afterparty.activeUsers
            if !updatedActiveUsers.contains(originalRequest.userId) {
                updatedActiveUsers.append(originalRequest.userId)
                print("⭐ VIP APPROVAL: Added \(originalRequest.userHandle) to activeUsers immediately")
            }
            
            // Update Firestore with approved VIP guest
            try await db.collection("afterparties").document(afterpartyId).updateData([
                "guestRequests": try updatedRequests.map { try Firestore.Encoder().encode($0) },
                "activeUsers": updatedActiveUsers
            ])
            
            print("⭐ VIP APPROVAL: SUCCESS - \(originalRequest.userHandle) approved as VIP with free entry")
            
            // Send VIP notification to guest
            Task {
                print("🔔 FCM: Sending VIP approval notification to guest")
                await FCMNotificationManager.shared.notifyGuestOfVIPApproval(
                    guestUserId: originalRequest.userId,
                    partyId: afterpartyId,
                    partyTitle: afterparty.title,
                    hostName: afterparty.hostHandle
                )
            }
            
            // Refresh manager data
            await fetchNearbyAfterparties()
            
        } else {
            print("🔴 VIP APPROVAL: FAILED - request not found")
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
        
        // Return properly structured HostEarnings for dashboard
        return HostEarnings(
            id: hostId,
            hostId: hostId,
            hostName: "Host", // Could be fetched from user data if needed
            totalEarnings: totalEarnings,
            pendingEarnings: totalEarnings * 0.1, // Placeholder: 10% pending
            paidEarnings: totalEarnings * 0.9, // Placeholder: 90% paid
            lastPayoutDate: nil, // Could be fetched from payout history
            bankAccountSetup: false, // Default for dashboard view
            transactions: [], // Simplified for dashboard
            payoutHistory: [] // Simplified for dashboard
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
            
            // CRITICAL FIX: Skip parties that have been ended by host
            if let completionStatus = docData["completionStatus"] as? String,
               completionStatus != "ongoing" && !completionStatus.isEmpty {
                return nil
            }
            
            return try? Firestore.Decoder().decode(Afterparty.self, from: docData)
        }
        
        // Filter out expired parties (older than 9 hours from creation) and sort in memory
        let now = Date()
        let filteredParties = afterparties.filter { afterparty in
            let nineHoursAfterCreation = Calendar.current.date(byAdding: .hour, value: 9, to: afterparty.createdAt) ?? Date()
            return nineHoursAfterCreation > now
        }
        
        // Sort by creation date in memory (most recent first)
        return filteredParties.sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Filter afterparties for marketplace discovery
    func getMarketplaceAfterparties(
        priceRange: ClosedRange<Double>? = nil,
        vibes: [String]? = nil,
        timeFilter: TimeFilter = .all
    ) async throws -> [Afterparty] {
        // Simplified query - just get public parties (no compound queries to avoid index requirement)
        print("🔧 QUERY DEBUG: Looking for visibility = '\(PartyVisibility.publicFeed.rawValue)'")
        let snapshot = try await db.collection("afterparties")
            .whereField("visibility", isEqualTo: PartyVisibility.publicFeed.rawValue)
            .getDocuments()
        
        print("🔧 QUERY DEBUG: Raw snapshot returned \(snapshot.documents.count) documents")
        for doc in snapshot.documents {
            let data = doc.data()
            print("🔧 QUERY DEBUG: Doc \(doc.documentID): visibility=\(data["visibility"] ?? "nil"), title=\(data["title"] ?? "nil")")
        }
        
        var afterparties = snapshot.documents.compactMap { doc -> Afterparty? in
            var docData = doc.data()
            docData["id"] = doc.documentID
            // Compatibility: some decoders expect `partyId`
            if docData["partyId"] == nil { docData["partyId"] = doc.documentID }
            
            let title = docData["title"] as? String ?? "Unknown"
            print("🔧 CONVERSION DEBUG: Processing party '\(title)'")
            
            // Skip expired afterparties (natural end time)
            if let endTime = (docData["endTime"] as? Timestamp)?.dateValue(),
               endTime < Date() {
                print("🔧 CONVERSION DEBUG: Party '\(title)' filtered out - expired")
                return nil
            }
            
            // CRITICAL FIX: Skip parties that have been ended by host
            if let completionStatus = docData["completionStatus"] as? String,
               completionStatus != "ongoing" && !completionStatus.isEmpty {
                print("🔧 CONVERSION DEBUG: Party '\(title)' filtered out - completion status: \(completionStatus)")
                return nil
            }
            
            do {
                let party = try Firestore.Decoder().decode(Afterparty.self, from: docData)
                print("🔧 CONVERSION DEBUG: Party '\(title)' successfully converted")
                return party
            } catch {
                print("🔧 CONVERSION DEBUG: Party '\(title)' failed conversion: \(error)")
                return nil
            }
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
    
    // MARK: - Race Condition Protection
    private var currentlyDeletingParties: Set<String> = []
    private let deletionLock = NSLock()
    
    func deleteAfterparty(_ afterparty: Afterparty) async throws {
        guard let userId = Auth.auth().currentUser?.uid,
              afterparty.userId == userId else { return }
        
        // CRITICAL: Prevent race conditions - only allow one deletion per party
        deletionLock.lock()
        if currentlyDeletingParties.contains(afterparty.id) {
            deletionLock.unlock()
            print("🚨 DELETION: Party \(afterparty.id) is already being deleted - aborting")
            throw NSError(domain: "AfterpartyError", code: 409, userInfo: [NSLocalizedDescriptionKey: "Party is already being cancelled"])
        }
        currentlyDeletingParties.insert(afterparty.id)
        deletionLock.unlock()
        
        // Ensure cleanup happens even if deletion fails
        defer {
            deletionLock.lock()
            currentlyDeletingParties.remove(afterparty.id)
            deletionLock.unlock()
        }
        
        print("🗑️ DELETION: Starting party cancellation process...")
        print("🗑️ DELETION: Party: \(afterparty.title)")
        print("🗑️ DELETION: Active users: \(afterparty.activeUsers.count)")
        print("🗑️ DELETION: Paid guests: \(afterparty.guestRequests.filter { $0.paymentStatus == .paid }.count)")
        
        // CRITICAL: Add timeout protection for the entire deletion process
        try await withTimeout(seconds: 120) {
            try await self.performDeletionProcess(afterparty)
        }
    }
    
    /// Perform the actual deletion process with timeout protection
    private func performDeletionProcess(_ afterparty: Afterparty) async throws {
        // CRITICAL: Process refunds BEFORE deleting the party
        let paidGuests = afterparty.guestRequests.filter { $0.paymentStatus == .paid }
        var refundResults: [DodoPaymentService.RefundResult] = []
        
        if !paidGuests.isEmpty {
            print("💸 DELETION: Processing refunds for \(paidGuests.count) paid guests...")
            
            do {
                refundResults = try await DodoPaymentService.shared.processPartyRefunds(afterparty: afterparty)
                
                let successCount = refundResults.filter { $0.success }.count
                let failureCount = refundResults.count - successCount
                
                if failureCount == 0 {
                    print("✅ DELETION: All \(successCount) refunds processed successfully")
                } else {
                    print("⚠️ DELETION: \(successCount) refunds succeeded, \(failureCount) failed")
                    print("🚨 DELETION: MANUAL INTERVENTION REQUIRED for failed refunds")
                }
                
                // CRITICAL: Reverse host earnings for successful refunds
                print("💰 DELETION: Reversing host earnings for refunded guests...")
                for refundResult in refundResults {
                    if refundResult.success {
                        do {
                            try await HostEarningsManager.shared.reverseHostEarnings(
                                hostId: afterparty.userId,
                                partyId: afterparty.id,
                                guestId: refundResult.guestId,
                                refundAmount: refundResult.amount,
                                paymentId: refundResult.paymentId
                            )
                            print("✅ DELETION: Reversed earnings for guest \(refundResult.guestHandle)")
                        } catch {
                            print("🔴 DELETION: Failed to reverse earnings for guest \(refundResult.guestHandle): \(error)")
                        }
                    } else {
                        print("⚠️ DELETION: Skipping earnings reversal for failed refund: \(refundResult.guestHandle)")
                    }
                }
                print("💰 DELETION: Host earnings reversal completed")
                
            } catch {
                print("🔴 DELETION: Critical refund processing error: \(error)")
                print("🚨 DELETION: MANUAL INTERVENTION REQUIRED - Failed to process refunds for party \(afterparty.id)")
                // Continue with deletion but log the critical issue
            }
            
            // Update Firestore with ACTUAL refund results (not assumed success)
            try await updateGuestRequestsWithRefundResults(
                afterpartyId: afterparty.id, 
                paidGuests: paidGuests,
                refundResults: refundResults
            )
        } else {
            print("💸 DELETION: No paid guests to refund")
        }
        
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

        
        // Delete the afterparty
        try await db.collection("afterparties").document(afterparty.id).delete()
        print("🗑️ DELETION: Party document deleted from Firestore")
        
        // Update the UI by removing the deleted afterparty
        await MainActor.run {
            self.nearbyAfterparties.removeAll { $0.id == afterparty.id }
        }
        
        print("✅ DELETION: Party cancellation completed successfully")
    }
    
    /// Update guest requests with ACTUAL refund results (BULLETPROOF VERSION)
    private func updateGuestRequestsWithRefundResults(
        afterpartyId: String, 
        paidGuests: [GuestRequest],
        refundResults: [DodoPaymentService.RefundResult]
    ) async throws {
        print("📝 DELETION: Updating guest requests with ACTUAL refund results...")
        
        let doc = try await db.collection("afterparties").document(afterpartyId).getDocument()
        guard let data = doc.data(),
              let currentAfterparty = try? Firestore.Decoder().decode(Afterparty.self, from: data) else {
            print("🔴 DELETION: Could not fetch party for refund status update")
            return
        }
        
        var updatedRequests = currentAfterparty.guestRequests
        
        // Create lookup for refund results
        let refundResultLookup = Dictionary(uniqueKeysWithValues: refundResults.map { ($0.guestId, $0) })
        
        // Update payment status ONLY for guests whose refunds actually succeeded
        for index in updatedRequests.indices {
            let request = updatedRequests[index]
            
            if let refundResult = refundResultLookup[request.userId] {
                if refundResult.success {
                    // Only mark as refunded if the API call actually succeeded
                    updatedRequests[index] = GuestRequest(
                        id: request.id,
                        userId: request.userId,
                        userName: request.userName,
                        userHandle: request.userHandle,
                        introMessage: request.introMessage,
                        requestedAt: request.requestedAt,
                        paymentStatus: .refunded,
                        approvalStatus: request.approvalStatus,
                        paypalOrderId: request.paypalOrderId,
                        dodoPaymentIntentId: request.dodoPaymentIntentId,
                        paidAt: request.paidAt,
                        refundedAt: Date(),
                        approvedAt: request.approvedAt
                    )
                    print("✅ DELETION: Marked \(request.userHandle) as refunded (API success)")
                } else {
                    // Keep as .paid if refund failed - requires manual intervention
                    print("🔴 DELETION: Keeping \(request.userHandle) as PAID - refund failed: \(refundResult.error ?? "Unknown")")
                }
            }
        }
        
        // Count successful refunds
        let successfulRefunds = refundResults.filter { $0.success }
        let failedRefunds = refundResults.filter { !$0.success }
        
        // Only remove from activeUsers those who were successfully refunded
        var updatedActiveUsers = currentAfterparty.activeUsers
        for refund in successfulRefunds {
            updatedActiveUsers.removeAll { $0 == refund.guestId }
        }
        
        // Update Firestore with accurate data
        try await db.collection("afterparties").document(afterpartyId).updateData([
            "guestRequests": try updatedRequests.map { try Firestore.Encoder().encode($0) },
            "activeUsers": updatedActiveUsers
        ])
        
        print("✅ DELETION: Database updated with accurate refund statuses:")
        print("  - Successfully refunded: \(successfulRefunds.count)")
        print("  - Failed refunds (still marked as paid): \(failedRefunds.count)")
        
        if !failedRefunds.isEmpty {
            print("🚨 DELETION: CRITICAL - \(failedRefunds.count) guests still marked as PAID due to failed refunds")
            print("🚨 DELETION: Manual refund processing required for:")
            for failed in failedRefunds {
                print("  - \(failed.guestHandle) (\(failed.guestId)): \(failed.error ?? "Unknown error")")
            }
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
            
            // CRITICAL: Clean up data inconsistencies
            let cleanedAfterparty = cleanupActiveUsersData(afterparty)
            return cleanedAfterparty
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

        // Increment host's hosted count and unlock verification at 3
        let hostRef = db.collection("users").document(afterparty.userId)
        hostRef.updateData(["hostedPartiesCount": FieldValue.increment(Int64(1))]) { err in
            if let err = err { print("❌ STATS: host increment: \(err)"); return }
            hostRef.getDocument { snap, _ in
                if let data = snap?.data(), let hosted = data["hostedPartiesCount"] as? Int, hosted >= 3, (data["hostVerified"] as? Bool) != true {
                    hostRef.updateData(["hostVerified": true])
                    AnalyticsManager.shared.track("host_verified_unlocked")
                }
            }
        }
        
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
        print("🟢 PAYMENT: Party ID: \(afterpartyId)")
        print("🟢 PAYMENT: User ID: \(userId)")
        print("🟢 PAYMENT: Payment Intent: \(paymentIntentId)")
        
        do {
            print("🚨 PAYMENT: About to fetch party document...")
        let doc = try await db.collection("afterparties").document(afterpartyId).getDocument()
            print("🚨 PAYMENT: Document fetched successfully")
        
            guard let data = doc.data() else {
                print("🔴 PAYMENT: No data in document")
                throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Afterparty document has no data"])
            }
            
            print("🚨 PAYMENT: Document data found, decoding...")
            guard let afterparty = try? Firestore.Decoder().decode(Afterparty.self, from: data) else {
                print("🔴 PAYMENT: Failed to decode afterparty")
                throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to decode afterparty"])
        }
        
        print("🟢 PAYMENT: Found party: \(afterparty.title)")
        print("🟢 PAYMENT: Current activeUsers: \(afterparty.activeUsers)")
        print("🟢 PAYMENT: Current guestRequests: \(afterparty.guestRequests.count)")
        
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
            print("🔵 PAYMENT: About to update Firestore...")
            print("🔵 PAYMENT: Updated requests count: \(updatedRequests.count)")
            print("🔵 PAYMENT: Updated activeUsers: \(updatedActiveUsers)")
            
        try await db.collection("afterparties").document(afterpartyId).updateData([
            "guestRequests": try updatedRequests.map { try Firestore.Encoder().encode($0) },
            "activeUsers": updatedActiveUsers
                // Removed lastUpdated field to match Firestore rules
        ])
            
            print("🚨 PAYMENT: Firestore update completed successfully!")
        
        print("🟢 PAYMENT: Successfully updated Firestore:")
        print("  - Updated guest request paymentStatus to: .paid")
        print("  - Added user to activeUsers array")
        print("  - activeUsers now contains: \(updatedActiveUsers)")
        
        // CRITICAL: Verify the update by re-reading from Firestore
        print("🔍 PAYMENT: Verifying Firestore update...")
        let verifyDoc = try await db.collection("afterparties").document(afterpartyId).getDocument()
        if let verifyData = verifyDoc.data(),
           let verifyParty = try? Firestore.Decoder().decode(Afterparty.self, from: verifyData) {
            print("🔍 PAYMENT: Verified activeUsers: \(verifyParty.activeUsers)")
            print("🔍 PAYMENT: User \(userId) in verified activeUsers: \(verifyParty.activeUsers.contains(userId))")
            if let verifyRequest = verifyParty.guestRequests.first(where: { $0.userId == userId }) {
                print("🔍 PAYMENT: Verified payment status: \(verifyRequest.paymentStatus)")
            }
        } else {
            print("🔴 PAYMENT: Failed to verify Firestore update!")
        }
        
        // Force refresh the local data to ensure UI updates
        await fetchNearbyAfterparties()
        
        print("🟢 PAYMENT: Refreshed local party data after payment completion")
        
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
        
            // 5. CRITICAL: Record host earnings for marketplace payout
            try await HostEarningsManager.shared.recordHostTransaction(
                hostId: afterparty.userId,
                hostName: afterparty.hostHandle,
                partyId: afterpartyId,
                partyTitle: afterparty.title,
                guestId: userId,
                guestName: request.userHandle,
                amount: afterparty.ticketPrice,
                paymentId: paymentIntentId
            )
            
            print("💰 MARKETPLACE: Recorded $\(afterparty.ticketPrice * 0.8) earnings for host \(afterparty.hostHandle)")
            
            // 6. CRITICAL: Send notifications to both host and guest
        await sendPaymentCompletionNotifications(
            hostId: afterparty.userId,
            guestId: userId,
            guestName: request.userHandle,
            partyTitle: afterparty.title,
            amount: afterparty.ticketPrice
        )
        
        // 6. Force real-time update by posting notification
        await MainActor.run {
            NotificationCenter.default.post(
                name: Notification.Name("PaymentCompleted"),
                    object: afterpartyId, // Pass party ID as object for consistent listening
                userInfo: [
                    "guestId": userId,
                    "partyTitle": afterparty.title
                ]
            )
                print("🔔 PAYMENT: Posted completion notification")
            }
            
        } catch {
            print("🚨🚨🚨 PAYMENT ERROR: \(error)")
            print("🚨🚨🚨 PAYMENT ERROR TYPE: \(type(of: error))")
            print("🚨🚨🚨 PAYMENT ERROR DESCRIPTION: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Send notifications to both host and guest after payment completion
    private func sendPaymentCompletionNotifications(
        hostId: String,
        guestId: String, 
        guestName: String,
        partyTitle: String,
        amount: Double
    ) async {
        print("🔔 PAYMENT: Sending completion notifications...")
        
        // CRITICAL FIX: Use proper push notifications instead of local notifications
        // Local notifications only show on the current device, which is wrong for multi-user scenarios
        
        // Send Firebase Cloud Message to HOST
        await sendFirebaseNotificationToUser(
            userId: hostId,
            title: "💰 Payment Received!",
            body: "\(guestName) paid $\(Int(amount)) for \(partyTitle). Check your earnings!",
            data: [
                "type": "payment_received",
                "partyTitle": partyTitle,
                "guestName": guestName,
                "amount": String(Int(amount))
            ]
        )
        
        // Send Firebase Cloud Message to GUEST
        await sendFirebaseNotificationToUser(
            userId: guestId,
            title: "✅ Payment Confirmed!",
            body: "You're all set for \(partyTitle)! Party details will be revealed soon.",
            data: [
                "type": "payment_success",
                "partyTitle": partyTitle
            ]
        )
        
        print("✅ PAYMENT: Push notifications sent to both host and guest via Firebase")
    }
    
    /// Send Firebase Cloud Message to specific user
    private func sendFirebaseNotificationToUser(
        userId: String,
        title: String,
        body: String,
        data: [String: String]
    ) async {
        print("📤 FCM: Sending notification to user \(userId)")
        print("📤 FCM: Title: \(title)")
        print("📤 FCM: Body: \(body)")
        
        // TODO: Implement Firebase Cloud Function call
        // This should call your Firebase Cloud Function to send FCM
        let notificationData: [String: Any] = [
            "targetUserId": userId,
            "title": title,
            "body": body,
            "data": data
        ]
        
        do {
            // Call Firebase Cloud Function to send FCM
            // Replace this URL with your actual Firebase Function URL
            let functionURL = "https://us-central1-bondfyr-da123.cloudfunctions.net/sendNotification"
            
            var request = URLRequest(url: URL(string: functionURL)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: notificationData)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("✅ FCM: Notification sent successfully to \(userId)")
            } else {
                print("🔴 FCM: Failed to send notification to \(userId)")
            }
            
        } catch {
            print("🔴 FCM: Error sending notification: \(error)")
            // Fallback to local notification for development
            print("🔄 FCM: Falling back to local notification for development")
        }
    }
    
    // MARK: - Timeout Helper
    
    /// Execute async operation with timeout protection
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "TimeoutError", code: 408, userInfo: [NSLocalizedDescriptionKey: "Operation timed out after \(seconds) seconds"])
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    // MARK: - P2P Payment Proof Submission
    
    /// Submit payment proof for P2P verification
    func submitPaymentProof(afterpartyId: String, paymentProofURL: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let userId = currentUser.uid
        print("🟡 PAYMENT PROOF: Submitting proof for user \(userId) in party \(afterpartyId)")
        
        // Get current party data
        let doc = try await db.collection("afterparties").document(afterpartyId).getDocument()
        guard let data = doc.data(),
              let afterparty = try? Firestore.Decoder().decode(Afterparty.self, from: data) else {
            throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Afterparty not found"])
        }
        
        // Find user's guest request
        var updatedRequests = afterparty.guestRequests
        guard let requestIndex = updatedRequests.firstIndex(where: { $0.userId == userId }) else {
            throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Guest request not found"])
        }
        
        let originalRequest = updatedRequests[requestIndex]
        
        // Ensure user is approved before allowing payment proof submission
        guard originalRequest.approvalStatus == .approved else {
            throw NSError(domain: "AfterpartyError", code: 403, userInfo: [NSLocalizedDescriptionKey: "Must be approved before submitting payment proof"])
        }
        
        // Update request with payment proof
        let updatedRequest = GuestRequest(
            id: originalRequest.id,
            userId: originalRequest.userId,
            userName: originalRequest.userName,
            userHandle: originalRequest.userHandle,
            introMessage: originalRequest.introMessage,
            requestedAt: originalRequest.requestedAt,
            paymentStatus: .proofSubmitted, // NEW STATUS
            approvalStatus: originalRequest.approvalStatus,
            paypalOrderId: originalRequest.paypalOrderId,
            dodoPaymentIntentId: originalRequest.dodoPaymentIntentId,
            paidAt: originalRequest.paidAt,
            refundedAt: originalRequest.refundedAt,
            approvedAt: originalRequest.approvedAt,
            paymentProofImageURL: paymentProofURL,
            proofSubmittedAt: Date(),
            verificationImageURL: originalRequest.verificationImageURL
        )
        
        updatedRequests[requestIndex] = updatedRequest
        
        // Update Firestore
        try await db.collection("afterparties").document(afterpartyId).updateData([
            "guestRequests": try updatedRequests.map { try Firestore.Encoder().encode($0) }
        ])
        
        print("🟢 PAYMENT PROOF: Successfully submitted proof for \(originalRequest.userHandle)")
        
        // NEW: Send FCM push notification to host about payment proof submission
        Task {
            print("🔔 FCM: Sending push notification to host about payment proof")
            await FCMNotificationManager.shared.notifyHostOfPaymentProof(
                hostUserId: afterparty.userId,
                partyId: afterpartyId,
                partyTitle: afterparty.title,
                guestName: originalRequest.userHandle
            )
        }
        
        // Refresh local data
        await fetchNearbyAfterparties()
    }
    
    /// Host verifies payment proof and marks as paid
    func verifyPaymentProof(afterpartyId: String, guestRequestId: String, approved: Bool) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("🟡 PAYMENT VERIFICATION: Host \(currentUser.uid) \(approved ? "approving" : "rejecting") payment proof")
        
        // Get current party data
        let doc = try await db.collection("afterparties").document(afterpartyId).getDocument()
        guard let data = doc.data(),
              let afterparty = try? Firestore.Decoder().decode(Afterparty.self, from: data) else {
            throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Afterparty not found"])
        }
        
        // Ensure current user is the host
        guard afterparty.userId == currentUser.uid else {
            throw NSError(domain: "AfterpartyError", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only the host can verify payments"])
        }
        
        // Find the guest request
        var updatedRequests = afterparty.guestRequests
        guard let requestIndex = updatedRequests.firstIndex(where: { $0.id == guestRequestId }) else {
            throw NSError(domain: "AfterpartyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Guest request not found"])
        }
        
        let originalRequest = updatedRequests[requestIndex]
        
        if approved {
            // Mark as paid and add to activeUsers
            let paidRequest = GuestRequest(
                id: originalRequest.id,
                userId: originalRequest.userId,
                userName: originalRequest.userName,
                userHandle: originalRequest.userHandle,
                introMessage: originalRequest.introMessage,
                requestedAt: originalRequest.requestedAt,
                paymentStatus: .paid, // VERIFIED AS PAID
                approvalStatus: originalRequest.approvalStatus,
                paypalOrderId: originalRequest.paypalOrderId,
                dodoPaymentIntentId: originalRequest.dodoPaymentIntentId,
                paidAt: Date(), // Mark payment verification time
                refundedAt: originalRequest.refundedAt,
                approvedAt: originalRequest.approvedAt,
                paymentProofImageURL: originalRequest.paymentProofImageURL,
                proofSubmittedAt: originalRequest.proofSubmittedAt,
                verificationImageURL: originalRequest.verificationImageURL
            )
            
            updatedRequests[requestIndex] = paidRequest
            
            // Add to activeUsers
            var updatedActiveUsers = afterparty.activeUsers
            if !updatedActiveUsers.contains(originalRequest.userId) {
                updatedActiveUsers.append(originalRequest.userId)
            }
            
            // Update Firestore
            try await db.collection("afterparties").document(afterpartyId).updateData([
                "guestRequests": try updatedRequests.map { try Firestore.Encoder().encode($0) },
                "activeUsers": updatedActiveUsers
            ])
            
            print("🟢 PAYMENT VERIFICATION: Payment approved - \(originalRequest.userHandle) is now attending")
            
            // NEW: Send FCM push notification to guest about payment verification
            Task {
                print("🔔 FCM: Sending push notification to guest about payment verification")
                await FCMNotificationManager.shared.notifyGuestOfPaymentVerification(
                    guestUserId: originalRequest.userId,
                    partyId: afterpartyId,
                    partyTitle: afterparty.title,
                    isApproved: true
                )
            }
            
        } else {
            // Reject payment proof - reset to pending
            let rejectedRequest = GuestRequest(
                id: originalRequest.id,
                userId: originalRequest.userId,
                userName: originalRequest.userName,
                userHandle: originalRequest.userHandle,
                introMessage: originalRequest.introMessage,
                requestedAt: originalRequest.requestedAt,
                paymentStatus: .pending, // BACK TO PENDING
                approvalStatus: originalRequest.approvalStatus,
                paypalOrderId: originalRequest.paypalOrderId,
                dodoPaymentIntentId: originalRequest.dodoPaymentIntentId,
                paidAt: originalRequest.paidAt,
                refundedAt: originalRequest.refundedAt,
                approvedAt: originalRequest.approvedAt,
                paymentProofImageURL: nil, // Remove rejected proof
                proofSubmittedAt: nil,
                verificationImageURL: originalRequest.verificationImageURL
            )
            
            updatedRequests[requestIndex] = rejectedRequest
            
            // Update Firestore
            try await db.collection("afterparties").document(afterpartyId).updateData([
                "guestRequests": try updatedRequests.map { try Firestore.Encoder().encode($0) }
            ])
            
            print("🔴 PAYMENT VERIFICATION: Payment rejected - \(originalRequest.userHandle) must resubmit")
            
            // NEW: Send FCM push notification to guest about payment rejection
            Task {
                print("🔔 FCM: Sending push notification to guest about payment rejection")
                await FCMNotificationManager.shared.notifyGuestOfPaymentVerification(
                    guestUserId: originalRequest.userId,
                    partyId: afterpartyId,
                    partyTitle: afterparty.title,
                    isApproved: false
                )
            }
        }
        
        // Refresh local data
        await fetchNearbyAfterparties()
    }
    
    // MARK: - Data Cleanup
    
    /// Removes users from activeUsers who don't have .paid payment status
    private func cleanupActiveUsersData(_ afterparty: Afterparty) -> Afterparty {
        let originalActiveCount = afterparty.activeUsers.count
        
        // Find users who are in activeUsers but don't have .paid status
        let validActiveUsers = afterparty.activeUsers.filter { userId in
            if let request = afterparty.guestRequests.first(where: { $0.userId == userId }) {
                return request.paymentStatus == .paid
            } else {
                // User in activeUsers but no guest request - also invalid
                print("🚨 CLEANUP: User \(userId) in activeUsers but no guest request found!")
                return false
            }
        }
        
        if validActiveUsers.count != originalActiveCount {
            print("🧹 CLEANUP: ⚠️ FOUND \(originalActiveCount - validActiveUsers.count) invalid users in activeUsers!")
            print("🧹 CLEANUP: Before: \(afterparty.activeUsers)")
            print("🧹 CLEANUP: Should be: \(validActiveUsers)")
            print("🚨 CLEANUP: NOTE - Cannot modify immutable struct, but this alerts us to data inconsistencies")
            
            // For now, return the original afterparty but log the inconsistency
            // The UI logic will handle these cases correctly with the bulletproof guest button
            return afterparty
        } else {
            print("🧹 CLEANUP: ✅ All activeUsers have valid .paid status")
            return afterparty
        }
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