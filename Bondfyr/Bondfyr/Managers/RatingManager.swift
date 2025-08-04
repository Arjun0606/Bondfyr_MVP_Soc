import Foundation
import FirebaseFirestore
import FirebaseAuth

class RatingManager: ObservableObject {
    static let shared = RatingManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Host Reputation System
    
    /// Submit a rating for a party and trigger host credit evaluation
    func submitPartyRating(
        partyId: String,
        rating: Int,
        comment: String? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              rating >= 1 && rating <= 5 else {
            completion(.failure(RatingError.invalidInput))
            return
        }
        
        let partyRef = db.collection("afterparties").document(partyId)
        
        // First, check if user already rated this party
        partyRef.getDocument { [weak self] snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data(),
                  let party = try? Firestore.Decoder().decode(Afterparty.self, from: data) else {
                completion(.failure(RatingError.partyNotFound))
                return
            }
            
            // Check if user already rated
            if let existingRatings = party.ratingsSubmitted,
               existingRatings[currentUserId] != nil {
                completion(.failure(RatingError.alreadyRated))
                return
            }
            
            // Submit the rating
            Task {
                do {
                    try await self?.submitRatingToFirestore(
                        partyRef: partyRef,
                        userId: currentUserId,
                        rating: rating,
                        comment: comment,
                        party: party
                    )
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func submitRatingToFirestore(
        partyRef: DocumentReference,
        userId: String,
        rating: Int,
        comment: String?,
        party: Afterparty
    ) async throws {
        var updateData: [String: Any] = [
            "ratingsSubmitted.\(userId)": rating,
            "lastRatedAt": FieldValue.serverTimestamp()
        ]
        
        if let comment = comment, !comment.isEmpty {
            updateData["comments.\(userId)"] = comment
        }
        
        // If this is the first rating, set ratingsRequired
        if party.ratingsRequired == nil {
            updateData["ratingsRequired"] = party.activeUsers.count
        }
        
        try await partyRef.updateData(updateData)
        
        // Update user's lastRatedPartyId
        updateUserLastRatedParty(userId: userId, partyId: party.id)
        
        // CRITICAL: Record guest attendance when they rate
        await recordGuestCheckIn(userId: userId)
        
        // Check if host should receive credit
        await evaluateHostCredit(for: party.id, hostId: party.userId)
    }
    
    private func updateUserLastRatedParty(userId: String, partyId: String) {
        let userRef = db.collection("users").document(userId)
        userRef.updateData(["lastRatedPartyId": partyId]) { error in
            if let error = error {
                print("❌ Error updating user lastRatedPartyId: \(error)")
            } else {
                print("✅ User lastRatedPartyId updated")
            }
        }
    }
    
    /// Evaluate if host should receive credit based on 20% rating threshold
    private func evaluateHostCredit(for partyId: String, hostId: String) async {
        let partyRef = db.collection("afterparties").document(partyId)
        
        do {
            let snapshot = try await partyRef.getDocument()
            guard let data = snapshot.data(),
                  let ratingsSubmitted = data["ratingsSubmitted"] as? [String: Int],
                  let ratingsRequired = data["ratingsRequired"] as? Int,
                  let hostCreditAwarded = data["hostCreditAwarded"] as? Bool else {
                return
            }
            
            // Don't award credit if already awarded
            if hostCreditAwarded { return }
            
            let ratingsCount = ratingsSubmitted.count
            let threshold = max(1, Int(ceil(Double(ratingsRequired) * 0.20))) // At least 20%
            
            print("📊 RATING EVALUATION: \(ratingsCount)/\(ratingsRequired) ratings (\(threshold) needed)")
            
            if ratingsCount >= threshold {
                await awardHostCredit(partyId: partyId, hostId: hostId)
            }
        } catch {
            print("❌ Error evaluating host credit: \(error.localizedDescription)")
        }
    }
    
    /// Award host credit and check for verification
    private func awardHostCredit(partyId: String, hostId: String) async {
        let batch = db.batch()
        
        // Mark party as credit awarded
        let partyRef = db.collection("afterparties").document(partyId)
        batch.updateData(["hostCreditAwarded": true], forDocument: partyRef)
        
        // Increment host's hostedPartiesCount
        let hostRef = db.collection("users").document(hostId)
        batch.updateData([
            "hostedPartiesCount": FieldValue.increment(Int64(1))
        ], forDocument: hostRef)
        
        do {
            try await batch.commit()
            print("✅ Host credit awarded for party \(partyId)")
            
            // Award First Host Achievement if this is their first credited party
            let hostSnapshot = try await hostRef.getDocument()
            if let hostedCount = hostSnapshot.data()?["hostedPartiesCount"] as? Int, hostedCount == 1 {
                await awardAchievement(userId: hostId, type: "first_party_hosted", title: "First Host", description: "Successfully hosted your first afterparty", emoji: "🎉")
            }
            
            // Check for host verification
            await checkHostVerification(hostId: hostId)
            
            // Send achievement notification
            await FCMNotificationManager.shared.sendAchievementNotification(
                to: hostId, 
                message: "Great job hosting! Keep it up to earn more achievements."
            )
        } catch {
            print("❌ Error awarding host credit: \(error)")
        }
    }
    
    private func checkHostVerification(hostId: String) async {
        let hostRef = db.collection("users").document(hostId)
        
        do {
            let snapshot = try await hostRef.getDocument()
            guard let data = snapshot.data(),
                  let hostedCount = data["hostedPartiesCount"] as? Int,
                  let isVerified = data["isHostVerified"] as? Bool else {
                return
            }
            
            if hostedCount >= 3 && !isVerified {
                try await hostRef.updateData(["isHostVerified": true])
                print("🏆 Host verification achieved!")
                
                // Award Host Verification Achievement
                await awardAchievement(userId: hostId, type: "host_verified", title: "Verified Host", description: "Verified as a trusted host", emoji: "🏆")
                
                await FCMNotificationManager.shared.sendHostVerificationNotification(to: hostId)
            }
        } catch {
            print("❌ Error checking host verification: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Guest Reputation Logic
    
    /// Records when a guest checks into a party
    func recordGuestCheckIn(userId: String) async {
        await incrementGuestAttendedCount(userId: userId)
    }
    
    /// Increments guest's attended count when they check in
    func incrementGuestAttendedCount(userId: String) async {
        let userRef = db.collection("users").document(userId)
        
        do {
            try await userRef.updateData([
                "attendedPartiesCount": FieldValue.increment(Int64(1)),
                "lastActiveParty": FieldValue.serverTimestamp()
            ])
            
            print("✅ Guest attended count incremented")
            
            // Award First Party Achievement if this is their first party
            if try await userRef.getDocument().data()?["attendedPartiesCount"] as? Int == 1 {
                await awardAchievement(userId: userId, type: "first_party_attended", title: "Party Goer", description: "Attended your first afterparty", emoji: "🕺")
            }
            
            // Check for guest verification
            await checkGuestVerification(userId: userId)
            
        } catch {
            print("❌ Error recording guest check-in: \(error)")
        }
    }
    
    private func checkGuestVerification(userId: String) async {
        let userRef = db.collection("users").document(userId)
        
        do {
            let snapshot = try await userRef.getDocument()
            guard let data = snapshot.data(),
                  let attendedCount = data["attendedPartiesCount"] as? Int,
                  let isVerified = data["isGuestVerified"] as? Bool else {
                return
            }
            
            if attendedCount >= 5 && !isVerified {
                try await userRef.updateData(["isGuestVerified": true])
                print("⭐ Guest verification achieved!")
                
                // Award Guest Verification Achievement
                await awardAchievement(userId: userId, type: "guest_verified", title: "Verified Guest", description: "Verified as an active community member", emoji: "⭐")
                
                await FCMNotificationManager.shared.sendGuestVerificationNotification(to: userId)
            }
        } catch {
            print("❌ Error checking guest verification: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Party End Logic
    
    /// Called when host ends a party - sets up the rating flow
    func hostEndParty(_ party: Afterparty) async {
        let partyRef = db.collection("afterparties").document(party.id)
        
        do {
            try await partyRef.updateData([
                "completionStatus": "host_ended",
                "endedAt": FieldValue.serverTimestamp(),
                "endedBy": party.userId,
                "ratingsRequired": party.activeUsers.count,
                "hostCreditAwarded": false
            ])
            
            print("✅ Party \(party.title) ended by host, rating flow initiated")
            
            // Send rating request notifications to all checked-in users
            await sendRatingRequestNotifications(partyId: party.id, userIds: party.activeUsers)
            
        } catch {
            print("❌ Error ending party: \(error)")
        }
    }
    
    /// Sets up rating requirements when a party ends
    func setupPartyRatingFlow(for partyId: String, checkedInUsers: [String]) async {
        let partyRef = db.collection("afterparties").document(partyId)
        
        do {
            try await partyRef.updateData([
                "activeUsers": checkedInUsers,
                "ratingsRequired": checkedInUsers.count,
                "hostCreditAwarded": false
            ])
            
            print("✅ Rating flow setup for party \(partyId) with \(checkedInUsers.count) potential raters")
            
            // Send rating request notifications to checked-in users
            for userId in checkedInUsers {
                NotificationManager.shared.sendRatingRequestNotification(
                    to: userId,
                    partyTitle: "Party", // Placeholder, actual title will be fetched
                    partyId: partyId
                )
            }
            
        } catch {
            print("❌ Error setting up rating flow: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Notification Helpers
    
    private func sendHostAchievementNotification(hostId: String) {
        // Send push notification for new hosted party credit
        NotificationManager.shared.sendAchievementNotification(
            to: hostId,
            message: "🎉 You received host credit! Your party was rated by enough guests."
        )
    }
    
    /// Send rating request notifications to all checked-in guests
    func sendRatingRequestNotifications(for party: Afterparty) {
        for userId in party.activeUsers {
            NotificationManager.shared.sendRatingRequestNotification(
                to: userId,
                partyTitle: party.title,
                partyId: party.id
            )
        }
    }
    
    /// Send rating request notifications to all checked-in guests
    func sendRatingRequestNotifications(partyId: String, userIds: [String]) async {
        for userId in userIds {
            await FCMNotificationManager.shared.sendRatingRequestNotification(to: userId, partyId: partyId)
        }
    }
    
    // MARK: - Achievement System
    
    /// Awards an achievement to a user and stores it in Firestore
    private func awardAchievement(userId: String, type: String, title: String, description: String, emoji: String) async {
        do {
            let achievement: [String: Any] = [
                "id": UUID().uuidString,
                "type": type,
                "title": title,
                "description": description,
                "emoji": emoji,
                "earnedDate": FieldValue.serverTimestamp(),
                "userId": userId
            ]
            
            // Store achievement in user's achievements subcollection
            try await db.collection("users").document(userId).collection("achievements").addDocument(data: achievement)
            
            print("🎉 Achievement awarded: \(title) to user \(userId)")
            
        } catch {
            print("❌ Error awarding achievement: \(error.localizedDescription)")
        }
    }
}

// MARK: - Rating Errors

enum RatingError: LocalizedError {
    case invalidInput
    case partyNotFound
    case alreadyRated
    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Invalid rating input"
        case .partyNotFound:
            return "Party not found"
        case .alreadyRated:
            return "You have already rated this party"
        }
    }
} 