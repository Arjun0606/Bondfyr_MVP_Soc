import Foundation
import Firebase

class ReputationManager {
    static let shared = ReputationManager()
    private let db = Firestore.firestore()
    
    private let hostVerificationThreshold = 4
    private let guestVerificationThreshold = 8
    
    private init() {}
    
    // This function should be called after an event has concluded.
    // It iterates through attendees and updates their counts.
    func updateUserStatsAfterEvent(event: Event, attendees: [AppUser]) {
        // Update host's stats
        updateHostStats(hostId: event.hostId)
        
        // Update guests' stats
        for attendee in attendees {
            updateGuestStats(guestId: attendee.uid)
        }
    }
    
    private func updateHostStats(hostId: String) {
        let hostRef = db.collection("users").document(hostId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let hostDocument: DocumentSnapshot
            do {
                try hostDocument = transaction.getDocument(hostRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            let currentHostedCount = hostDocument.data()?["hostedPartiesCount"] as? Int ?? 0
            let newHostedCount = currentHostedCount + 1
            
            transaction.updateData(["hostedPartiesCount": newHostedCount], forDocument: hostRef)
            
            if newHostedCount >= self.hostVerificationThreshold {
                transaction.updateData(["isHostVerified": true], forDocument: hostRef)
            }
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("Host stats update transaction failed: \(error)")
            } else {
                print("Host stats updated successfully for host \(hostId)")
            }
        }
    }
    
    private func updateGuestStats(guestId: String) {
        let guestRef = db.collection("users").document(guestId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let guestDocument: DocumentSnapshot
            do {
                try guestDocument = transaction.getDocument(guestRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            let currentAttendedCount = guestDocument.data()?["attendedPartiesCount"] as? Int ?? 0
            let newAttendedCount = currentAttendedCount + 1
            
            transaction.updateData(["attendedPartiesCount": newAttendedCount], forDocument: guestRef)
            
            if newAttendedCount >= self.guestVerificationThreshold {
                transaction.updateData(["isGuestVerified": true], forDocument: guestRef)
            }
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("Guest stats update transaction failed: \(error)")
            } else {
                print("Guest stats updated successfully for guest \(guestId)")
            }
        }
    }
    
    func submitRating(raterId: String, ratedId: String, eventId: String, rating: Double, comment: String?, ratedUserType: String) {
        let newRating = Rating(
            eventId: eventId,
            raterId: raterId,
            ratedId: ratedId,
            rating: rating,
            comment: comment,
            timestamp: Timestamp(date: Date()),
            ratedUserType: ratedUserType
        )
        
        // Add the rating to the "ratings" collection
        do {
            try db.collection("ratings").addDocument(from: newRating)
        } catch let error {
            print("Error writing rating to Firestore: \(error)")
            return
        }
        
        // Update the user's average rating in a transaction
        let userRef = db.collection("users").document(ratedId)
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let userDocument: DocumentSnapshot
            do {
                try userDocument = transaction.getDocument(userRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            let ratingField: String
            let countField: String
            
            if ratedUserType == "host" {
                ratingField = "hostRating"
                countField = "hostRatingsCount"
            } else {
                ratingField = "guestRating"
                countField = "guestRatingsCount"
            }
            
            let currentRating = userDocument.data()?[ratingField] as? Double ?? 0.0
            let currentCount = userDocument.data()?[countField] as? Int ?? 0
            
            let newCount = currentCount + 1
            let newAverageRating = ((currentRating * Double(currentCount)) + rating) / Double(newCount)
            
            transaction.updateData([
                ratingField: newAverageRating,
                countField: newCount
            ], forDocument: userRef)
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("Rating transaction failed: \(error)")
            } else {
                print("Rating and user stats updated successfully for user \(ratedId).")
            }
        }
    }
} 