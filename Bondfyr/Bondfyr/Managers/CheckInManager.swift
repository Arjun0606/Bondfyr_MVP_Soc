import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class CheckInManager: ObservableObject {
    static let shared = CheckInManager()
    
    private let db = Firestore.firestore()
    @Published var currentCheckIns: [CheckIn] = []
    @Published var activeCheckIn: CheckIn?
    
    func checkInToEvent(eventId: String, ticketId: String, completion: @escaping (Bool, String) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false, "User not logged in")
            return
        }
        
        // Check if user already has an active check-in
        fetchActiveCheckIns(userId: userId) { [weak self] checkIns in
            guard let self = self else { return }
            
            if let existingCheckIn = checkIns.first {
                // User already checked in somewhere
                completion(false, "You are already checked in at another event. Please check out first.")
                return
            }
            
            // Create a new check-in
            let checkIn = CheckIn(
                userId: userId,
                eventId: eventId,
                timestamp: Date(),
                ticketId: ticketId,
                isActive: true
            )
            
            do {
                try self.db.collection("check_ins").addDocument(from: checkIn) { error in
                    if let error = error {
                        completion(false, "Error checking in: \(error.localizedDescription)")
                    } else {
                        self.fetchActiveCheckIn(userId: userId)
                        
                        // 🔥 NEW: Record guest check-in for reputation system
                        Task {
                            await RatingManager.shared.recordGuestCheckIn(userId: userId)
                        }
                        // Increment attendance count and unlock guest verification
                        self.incrementAttendanceCounter(userId: userId)
                        AnalyticsManager.shared.track("check_in_success", ["event_id": eventId])
                        
                        completion(true, "Successfully checked in!")
                    }
                }
            } catch {
                completion(false, "Error encoding check-in: \(error.localizedDescription)")
            }
        }
    }
    
    func checkOut(completion: @escaping (Bool, String) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid,
              let checkInId = activeCheckIn?.id else {
            completion(false, "No active check-in found")
            return
        }
        
        // Update the check-in to inactive
        db.collection("check_ins").document(checkInId).updateData([
            "isActive": false
        ]) { error in
            if let error = error {
                completion(false, "Error checking out: \(error.localizedDescription)")
            } else {
                self.activeCheckIn = nil
                completion(true, "Successfully checked out")
            }
        }
    }
    
    func fetchActiveCheckIn(userId: String? = nil) {
        let uid = userId ?? Auth.auth().currentUser?.uid
        
        guard let uid = uid else { return }
        
        db.collection("check_ins")
            .whereField("userId", isEqualTo: uid)
            .whereField("isActive", isEqualTo: true)
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents,
                      let self = self else { return }
                
                let checkIns = documents.compactMap { try? $0.data(as: CheckIn.self) }
                self.activeCheckIn = checkIns.first
            }
    }
    
    private func fetchActiveCheckIns(userId: String, completion: @escaping ([CheckIn]) -> Void) {
        db.collection("check_ins")
            .whereField("userId", isEqualTo: userId)
            .whereField("isActive", isEqualTo: true)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let checkIns = documents.compactMap { try? $0.data(as: CheckIn.self) }
                completion(checkIns)
            }
    }
    
    func fetchEventAttendees(eventId: String, completion: @escaping ([String]) -> Void) {
        db.collection("check_ins")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("isActive", isEqualTo: true)
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let userIds = documents.compactMap { document -> String? in
                    return document.data()["userId"] as? String
                }
                
                completion(userIds)
            }
    }
    
    // MARK: - Stats updates
    private func incrementAttendanceCounter(userId: String) {
        let ref = db.collection("users").document(userId)
        ref.updateData(["attendedPartiesCount": FieldValue.increment(Int64(1))]) { err in
            if let err = err { print("❌ STATS: attendance increment: \(err)"); return }
            ref.getDocument { snap, _ in
                guard let data = snap?.data(), let attended = data["attendedPartiesCount"] as? Int else { return }
                if attended >= 5, (data["guestVerified"] as? Bool) != true {
                    ref.updateData(["guestVerified": true])
                    AnalyticsManager.shared.track("guest_verified_unlocked")
                }
            }
        }
    }

    // Check if user has checked in to a specific event
    func hasCheckedInToEvent(eventId: String) -> Bool {
        guard let checkIn = activeCheckIn else {
            return false
        }
        
        return checkIn.eventId == eventId && checkIn.isActive
    }
    
    // Get check-in time for a specific event
    func getCheckInTime(eventId: String) -> Date? {
        guard let checkIn = activeCheckIn, 
              checkIn.eventId == eventId,
              checkIn.isActive else {
            return nil
        }
        
        return checkIn.timestamp
    }
    
    // Venue-based check-in for Bondfyr 2.0
    func checkInToVenue(venueId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "CheckIn", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in."])) )
            return
        }
        let checkInData: [String: Any] = [
            "userId": userId,
            "venueId": venueId,
            "timestamp": FieldValue.serverTimestamp()
        ]
        db.collection("checkIns").addDocument(data: checkInData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
} 