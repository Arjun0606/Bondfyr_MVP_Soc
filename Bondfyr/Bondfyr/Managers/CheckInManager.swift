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
} 