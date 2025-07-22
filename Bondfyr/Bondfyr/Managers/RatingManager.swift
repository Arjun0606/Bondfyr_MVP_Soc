import Foundation
import FirebaseFirestore

@MainActor
class RatingManager: ObservableObject {
    static let shared = RatingManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Submit Rating
    
    /// Submit a guest's rating for a party and host
    func submitRating(_ rating: PartyRating) async {
        do {
            // Save individual rating
            try await db.collection("party_ratings").document(rating.id).setData(
                try Firestore.Encoder().encode(rating)
            )
            
            print("✅ RATING: Successfully saved rating \(rating.id)")
            
            // Update host's rating summary
            await updateHostRatingSummary(for: rating.hostId)
            
            // Mark party as having been rated by this guest
            await markPartyAsRated(partyId: rating.partyId, guestId: rating.guestId)
            
        } catch {
            print("🔴 RATING: Error saving rating - \(error)")
        }
    }
    
    // MARK: - Host Rating Summary
    
    /// Update aggregated rating data for a host
    private func updateHostRatingSummary(for hostId: String) async {
        do {
            // Get all ratings for this host
            let snapshot = try await db.collection("party_ratings")
                .whereField("hostId", isEqualTo: hostId)
                .getDocuments()
            
            let ratings = snapshot.documents.compactMap { doc -> PartyRating? in
                try? doc.data(as: PartyRating.self)
            }
            
            guard !ratings.isEmpty else { return }
            
            // Calculate averages
            let totalRatings = ratings.count
            let avgPartyRating = Double(ratings.map(\.partyRating).reduce(0, +)) / Double(totalRatings)
            let avgHostRating = Double(ratings.map(\.hostRating).reduce(0, +)) / Double(totalRatings)
            let overallAverage = (avgPartyRating + avgHostRating) / 2.0
            
            let summary = HostRatingSummary(
                hostId: hostId,
                totalRatings: totalRatings,
                averagePartyRating: avgPartyRating,
                averageHostRating: avgHostRating,
                overallAverage: overallAverage
            )
            
            // Save summary
            try await db.collection("host_ratings").document(hostId).setData(
                try Firestore.Encoder().encode(summary)
            )
            
            print("📊 RATING: Updated host summary - \(overallAverage.formatted(.number.precision(.fractionLength(1)))) stars (\(totalRatings) ratings)")
            
        } catch {
            print("🔴 RATING: Error updating host summary - \(error)")
        }
    }
    
    // MARK: - Party Completion Tracking
    
    /// Mark that a guest has rated a specific party
    private func markPartyAsRated(partyId: String, guestId: String) async {
        do {
            try await db.collection("afterparties").document(partyId).updateData([
                "ratedBy.\(guestId)": true,
                "lastRatedAt": FieldValue.serverTimestamp()
            ])
            
            print("✅ RATING: Marked party \(partyId) as rated by guest \(guestId)")
            
        } catch {
            print("🔴 RATING: Error marking party as rated - \(error)")
        }
    }
    
    // MARK: - Fetch Host Rating
    
    /// Get a host's current rating summary
    func getHostRating(for hostId: String) async -> HostRatingSummary? {
        do {
            let doc = try await db.collection("host_ratings").document(hostId).getDocument()
            return try doc.data(as: HostRatingSummary.self)
        } catch {
            print("🔴 RATING: Error fetching host rating - \(error)")
            return nil
        }
    }
    
    // MARK: - Check if Guest Can Rate
    
    /// Check if a guest has already rated a specific party
    func hasGuestRated(partyId: String, guestId: String) async -> Bool {
        do {
            let doc = try await db.collection("afterparties").document(partyId).getDocument()
            let data = doc.data()
            let ratedBy = data?["ratedBy"] as? [String: Bool] ?? [:]
            return ratedBy[guestId] == true
        } catch {
            print("🔴 RATING: Error checking if guest rated - \(error)")
            return false
        }
    }
    
    // MARK: - Host End Party
    
    /// Host ends the party - triggers rating notifications to all guests
    func hostEndParty(_ afterparty: Afterparty) async {
        do {
            // Update party status
            try await db.collection("afterparties").document(afterparty.id).updateData([
                "completionStatus": PartyCompletionStatus.hostEnded.rawValue,
                "endedAt": FieldValue.serverTimestamp(),
                "endedBy": afterparty.userId
            ])
            
            print("🏁 RATING: Host ended party \(afterparty.title)")
            
            // Send notifications to all active guests to rate
            await sendRatingNotifications(to: afterparty.activeUsers, for: afterparty)
            
        } catch {
            print("🔴 RATING: Error ending party - \(error)")
        }
    }
    
    /// Send rating notification to guests
    private func sendRatingNotifications(to guestIds: [String], for afterparty: Afterparty) async {
        // TODO: Implement push notifications
        print("🔔 RATING: Would send rating notifications to \(guestIds.count) guests")
        print("🔔 RATING: Notification: 'Rate your experience at \(afterparty.title)'")
    }
} 