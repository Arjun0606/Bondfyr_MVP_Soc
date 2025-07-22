import Foundation
import Firebase

class ReputationManager {
    static let shared = ReputationManager()
    private let db = Firestore.firestore()
    
    // Simplified verification thresholds
    private let hostVerificationThreshold = 3    // Down from 4
    private let guestVerificationThreshold = 5   // Down from 8
    
    private init() {}
    
    // MARK: - Simple Stats Tracking
    
    /// Call this when a party ends successfully (had guests and completed)
    func updateUserStatsAfterEvent(afterparty: Afterparty, attendees: [AppUser]) {
        // Only update if party actually had guests and completed
        guard !attendees.isEmpty && afterparty.endTime <= Date() else {
            print("Party didn't complete successfully - not updating stats")
            return
        }
        
        // Calculate party duration in hours
        let partyDurationHours = Int(afterparty.endTime.timeIntervalSince(afterparty.startTime) / 3600)
        
        // Update host stats (only if party was successful)
        updateHostStats(hostId: afterparty.userId, partyHours: partyDurationHours)
        
        // Update guest stats (only for users who actually attended)
        for attendee in attendees {
            updateGuestStats(guestId: attendee.uid, partyHours: partyDurationHours)
        }
        
        // Check for new achievements
        checkAchievements(for: afterparty.userId, isHost: true)
        for attendee in attendees {
            checkAchievements(for: attendee.uid, isHost: false)
        }
    }
    
    private func updateHostStats(hostId: String, partyHours: Int) {
        let hostRef = db.collection("users").document(hostId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let hostDocument: DocumentSnapshot
            do {
                try hostDocument = transaction.getDocument(hostRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            let currentHosted = hostDocument.data()?["partiesHosted"] as? Int ?? 0
            let currentPartyHours = hostDocument.data()?["totalPartyHours"] as? Int ?? 0
            let newHosted = currentHosted + 1
            let newPartyHours = currentPartyHours + partyHours
            
            // Calculate account age accurately
            let accountCreated = (hostDocument.data()?["accountCreated"] as? Timestamp)?.dateValue() ?? Date()
            let accountAgeDays = Calendar.current.dateComponents([.day], from: accountCreated, to: Date()).day ?? 0
            
            var updateData: [String: Any] = [
                "partiesHosted": newHosted,
                "totalPartyHours": newPartyHours,
                "lastActiveParty": Timestamp(date: Date()),
                "accountAgeDays": max(accountAgeDays, 0)
            ]
            
            // Check for host verification (must have 3 SUCCESSFUL parties)
            if newHosted >= self.hostVerificationThreshold {
                updateData["isHostVerified"] = true
            }
            
            transaction.updateData(updateData, forDocument: hostRef)
            return nil
        }) { (object, error) in
            if let error = error {
                print("Error updating host stats: \(error)")
            } else {
                print("✅ Host stats updated: +1 party, +\(partyHours) hours")
            }
        }
    }
    
    private func updateGuestStats(guestId: String, partyHours: Int) {
        let guestRef = db.collection("users").document(guestId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let guestDocument: DocumentSnapshot
            do {
                try guestDocument = transaction.getDocument(guestRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            let currentAttended = guestDocument.data()?["partiesAttended"] as? Int ?? 0
            let currentPartyHours = guestDocument.data()?["totalPartyHours"] as? Int ?? 0
            let newAttended = currentAttended + 1
            let newPartyHours = currentPartyHours + partyHours
            
            // Calculate account age accurately
            let accountCreated = (guestDocument.data()?["accountCreated"] as? Timestamp)?.dateValue() ?? Date()
            let accountAgeDays = Calendar.current.dateComponents([.day], from: accountCreated, to: Date()).day ?? 0
            
            var updateData: [String: Any] = [
                "partiesAttended": newAttended,
                "totalPartyHours": newPartyHours,
                "lastActiveParty": Timestamp(date: Date()),
                "accountAgeDays": max(accountAgeDays, 0)
            ]
            
            // Check for guest verification (must have attended 5 REAL parties)
            if newAttended >= self.guestVerificationThreshold {
                updateData["isGuestVerified"] = true
            }
            
            transaction.updateData(updateData, forDocument: guestRef)
            return nil
        }) { (object, error) in
            if let error = error {
                print("Error updating guest stats: \(error)")
            } else {
                print("✅ Guest stats updated: +1 party, +\(partyHours) hours")
            }
        }
    }
    
    // MARK: - Achievement System
    
    private func checkAchievements(for userId: String, isHost: Bool) {
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { [weak self] (document, error) in
            guard let self = self,
                  let document = document,
                  let data = document.data() else { return }
            
            let partiesHosted = data["partiesHosted"] as? Int ?? 0
            let partiesAttended = data["partiesAttended"] as? Int ?? 0
            let isHostVerified = data["isHostVerified"] as? Bool ?? false
            let isGuestVerified = data["isGuestVerified"] as? Bool ?? false
            
            var newAchievements: [SimpleAchievement] = []
            
            // First party achievements
            if isHost && partiesHosted == 1 {
                newAchievements.append(SimpleAchievement(type: .firstPartyHosted))
            }
            
            if !isHost && partiesAttended == 1 {
                newAchievements.append(SimpleAchievement(type: .firstPartyAttended))
            }
            
            // Verification achievements
            if isHost && isHostVerified && partiesHosted == self.hostVerificationThreshold {
                newAchievements.append(SimpleAchievement(type: .hostVerified))
            }
            
            if !isHost && isGuestVerified && partiesAttended == self.guestVerificationThreshold {
                newAchievements.append(SimpleAchievement(type: .guestVerified))
            }
            
            // Party milestone achievements
            let totalParties = partiesHosted + partiesAttended
            let milestones = [5, 10, 25, 50]
            
            for milestone in milestones {
                if totalParties == milestone {
                    newAchievements.append(SimpleAchievement(type: .partyMilestone, milestone: milestone))
                }
            }
            
            // Save achievements if any
            if !newAchievements.isEmpty {
                self.saveAchievements(newAchievements, for: userId)
            }
        }
    }
    
    func updateSocialConnection(for userId: String, platform: String, connected: Bool) {
        let userRef = db.collection("users").document(userId)
        let field = platform == "instagram" ? "instagramConnected" : "snapchatConnected"
        
        userRef.updateData([field: connected]) { [weak self] error in
            if error == nil && connected {
                // Check for social connector achievement
                userRef.getDocument { (document, error) in
                    guard let document = document,
                          let data = document.data() else { return }
                    
                    let instagramConnected = data["instagramConnected"] as? Bool ?? false
                    let snapchatConnected = data["snapchatConnected"] as? Bool ?? false
                    
                    if instagramConnected || snapchatConnected {
                        let achievement = SimpleAchievement(type: .socialConnector)
                        self?.saveAchievements([achievement], for: userId)
                    }
                }
            }
        }
    }
    
    private func saveAchievements(_ achievements: [SimpleAchievement], for userId: String) {
        let batch = db.batch()
        
        for achievement in achievements {
            let achievementRef = db.collection("users").document(userId)
                .collection("achievements").document(achievement.id)
            
            do {
                let data = try Firestore.Encoder().encode(achievement)
                batch.setData(data, forDocument: achievementRef)
            } catch {
                print("Error encoding achievement: \(error)")
            }
        }
        
        batch.commit { error in
            if let error = error {
                print("Error saving achievements: \(error)")
            } else {
                // Post notification for UI to show achievement
                NotificationCenter.default.post(
                    name: NSNotification.Name("NewAchievementEarned"),
                    object: achievements.first
                )
            }
        }
    }
    
    // MARK: - Fetch User Achievements
    
    func fetchUserAchievements(for userId: String, completion: @escaping ([SimpleAchievement]) -> Void) {
        db.collection("users").document(userId)
            .collection("achievements")
            .order(by: "earnedDate", descending: true)
            .getDocuments { (snapshot, error) in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let achievements = documents.compactMap { doc -> SimpleAchievement? in
                    try? doc.data(as: SimpleAchievement.self)
                }
                
                completion(achievements)
        }
    }
} 