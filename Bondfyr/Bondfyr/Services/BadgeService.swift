import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class BadgeService: ObservableObject {
    static let shared = BadgeService()
    private let db = Firestore.firestore()
    
    @Published var userBadges: [UserBadge] = []
    @Published var badgeProgress: BadgeProgress = BadgeProgress()
    @Published var verificationStatus: UserVerificationStatus = UserVerificationStatus(
        isVerifiedHost: false,
        isVerifiedPartyGoer: false,
        hostBadgeProgress: 0,
        partyGoerBadgeProgress: 0
    )
    @Published var isLoading = false
    @Published var error: Error?
    
    // Notification triggers
    @Published var showingNewBadgeNotification = false
    @Published var newlyEarnedBadge: UserBadge?
    @Published var showingProgressNotification = false
    @Published var progressNotificationText = ""
    
    private init() {
        loadUserBadges()
        loadBadgeProgress()
    }
    
    // MARK: - Data Loading
    
    private func loadUserBadges() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId).collection("badges")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let documents = snapshot?.documents else { return }
                
                self.userBadges = documents.compactMap { doc -> UserBadge? in
                    try? doc.data(as: UserBadge.self)
                }
                
                self.updateVerificationStatus()
            }
    }
    
    private func loadBadgeProgress() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId).collection("stats")
            .document("progress")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let data = snapshot?.data() else {
                    // Initialize with default values if no data exists
                    self?.createInitialBadgeProgress()
                    return
                }
                
                self.badgeProgress = BadgeProgress(
                    partiesHosted: data["partiesHosted"] as? Int ?? 0,
                    partiesAttended: data["partiesAttended"] as? Int ?? 0,
                    totalPhotoLikes: data["totalPhotoLikes"] as? Int ?? 0
                )
                
                self.checkBadgeProgress()
            }
    }
    
    private func createInitialBadgeProgress() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let initialProgress = BadgeProgress()
        
        do {
            try db.collection("users").document(userId).collection("stats")
                .document("progress")
                .setData(from: initialProgress)
            
            // Create initial badge set
            createInitialBadges()
        } catch {
            print("Error creating initial badge progress: \(error)")
        }
    }
    
    private func createInitialBadges() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let allBadgeTypes = BadgeType.allCases
        
        for badgeType in allBadgeTypes {
            let badge = UserBadge(
                id: "\(userId)_\(badgeType.rawValue)",
                type: badgeType,
                name: badgeType.rawValue,
                description: badgeType.description,
                earnedDate: nil,
                level: .locked,
                progress: 0,
                requirement: getRequirement(for: badgeType)
            )
            
            do {
                try db.collection("users").document(userId).collection("badges")
                    .document(badge.id)
                    .setData(from: badge)
            } catch {
                print("Error creating initial badge: \(error)")
            }
        }
    }
    
    private func getRequirement(for type: BadgeType) -> Int {
        switch type {
        case .verifiedHost:
            return 4
        case .verifiedPartyGoer:
            return 4
        case .socialStar:
            return 100
        case .partyLegend:
            return 20
        case .loyalGuest:
            return 15
        }
    }
    
    // MARK: - Progress Updates
    
    func incrementPartiesHosted() async {
        let newCount = badgeProgress.partiesHosted + 1
        await updateProgress(partiesHosted: newCount)
        
        // Check for verification milestone
        if newCount == 4 {
            await earnVerifiedHostBadge()
        }
        
        // Check for legend milestone
        if newCount == 20 {
            await earnBadge(type: .partyLegend, newProgress: newCount)
        }
        
        // Show progress notification for verification
        if newCount < 4 {
            showProgressNotification(text: "🎉 \(newCount)/4 parties hosted! \(4 - newCount) more to become a Verified Host!")
        }
    }
    
    func incrementPartiesAttended() async {
        let newCount = badgeProgress.partiesAttended + 1
        await updateProgress(partiesAttended: newCount)
        
        // Check for verification milestone
        if newCount == 4 {
            await earnVerifiedPartyGoerBadge()
        }
        
        // Check for loyal guest milestone
        if newCount == 15 {
            await earnBadge(type: .loyalGuest, newProgress: newCount)
        }
        
        // Show progress notification for verification
        if newCount < 4 {
            showProgressNotification(text: "🎊 \(newCount)/4 parties attended! \(4 - newCount) more to become a Verified Party Goer!")
        }
    }
    
    func incrementPhotoLikes() async {
        let newCount = badgeProgress.totalPhotoLikes + 1
        await updateProgress(totalPhotoLikes: newCount)
        
        // Check for social star milestone
        if newCount == 100 {
            await earnBadge(type: .socialStar, newProgress: newCount)
        }
        
        // Show progress notification
        if newCount < 100 && newCount % 10 == 0 {
            showProgressNotification(text: "⭐ \(newCount)/100 photo likes! Getting closer to Social Star!")
        }
    }
    
    private func updateProgress(partiesHosted: Int? = nil, partiesAttended: Int? = nil, totalPhotoLikes: Int? = nil) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        var updateData: [String: Any] = [:]
        
        if let hosted = partiesHosted {
            updateData["partiesHosted"] = hosted
            badgeProgress = BadgeProgress(
                partiesHosted: hosted,
                partiesAttended: badgeProgress.partiesAttended,
                totalPhotoLikes: badgeProgress.totalPhotoLikes
            )
        }
        
        if let attended = partiesAttended {
            updateData["partiesAttended"] = attended
            badgeProgress = BadgeProgress(
                partiesHosted: badgeProgress.partiesHosted,
                partiesAttended: attended,
                totalPhotoLikes: badgeProgress.totalPhotoLikes
            )
        }
        
        if let likes = totalPhotoLikes {
            updateData["totalPhotoLikes"] = likes
            badgeProgress = BadgeProgress(
                partiesHosted: badgeProgress.partiesHosted,
                partiesAttended: badgeProgress.partiesAttended,
                totalPhotoLikes: likes
            )
        }
        
        do {
            try await db.collection("users").document(userId).collection("stats")
                .document("progress")
                .setData(updateData, merge: true)
        } catch {
            print("Error updating progress: \(error)")
        }
    }
    
    // MARK: - Badge Earning
    
    private func earnVerifiedHostBadge() async {
        await earnBadge(type: .verifiedHost, newProgress: badgeProgress.partiesHosted)
        
        // Update verification status immediately
        verificationStatus = UserVerificationStatus(
            isVerifiedHost: true,
            isVerifiedPartyGoer: verificationStatus.isVerifiedPartyGoer,
            hostBadgeProgress: badgeProgress.partiesHosted,
            partyGoerBadgeProgress: verificationStatus.partyGoerBadgeProgress
        )
    }
    
    private func earnVerifiedPartyGoerBadge() async {
        await earnBadge(type: .verifiedPartyGoer, newProgress: badgeProgress.partiesAttended)
        
        // Update verification status immediately
        verificationStatus = UserVerificationStatus(
            isVerifiedHost: verificationStatus.isVerifiedHost,
            isVerifiedPartyGoer: true,
            hostBadgeProgress: verificationStatus.hostBadgeProgress,
            partyGoerBadgeProgress: badgeProgress.partiesAttended
        )
    }
    
    private func earnBadge(type: BadgeType, newProgress: Int) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let badgeId = "\(userId)_\(type.rawValue)"
        
        let earnedBadge = UserBadge(
            id: badgeId,
            type: type,
            name: type.rawValue,
            description: type.description,
            earnedDate: Date(),
            level: .earned,
            progress: newProgress,
            requirement: getRequirement(for: type)
        )
        
        do {
            try await db.collection("users").document(userId).collection("badges")
                .document(badgeId)
                .setData(from: earnedBadge)
            
            // Show notification
            showNewBadgeNotification(badge: earnedBadge)
            
        } catch {
            print("Error earning badge: \(error)")
        }
    }
    
    private func checkBadgeProgress() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Update all badges with current progress
        for badgeType in BadgeType.allCases {
            let currentProgress = getCurrentProgress(for: badgeType)
            let requirement = getRequirement(for: badgeType)
            
            let isEarned = currentProgress >= requirement
            let level: BadgeLevel = isEarned ? .earned : (currentProgress > 0 ? .inProgress : .locked)
            
            let badge = UserBadge(
                id: "\(userId)_\(badgeType.rawValue)",
                type: badgeType,
                name: badgeType.rawValue,
                description: badgeType.description,
                earnedDate: isEarned ? Date() : nil,
                level: level,
                progress: currentProgress,
                requirement: requirement
            )
            
            // Update in Firestore
            Task {
                do {
                    try await db.collection("users").document(userId).collection("badges")
                        .document(badge.id)
                        .setData(from: badge)
                } catch {
                    print("Error updating badge progress: \(error)")
                }
            }
        }
        
        updateVerificationStatus()
    }
    
    private func getCurrentProgress(for type: BadgeType) -> Int {
        switch type {
        case .verifiedHost, .partyLegend:
            return badgeProgress.partiesHosted
        case .verifiedPartyGoer, .loyalGuest:
            return badgeProgress.partiesAttended
        case .socialStar:
            return badgeProgress.totalPhotoLikes
        }
    }
    
    private func updateVerificationStatus() {
        let hostBadge = userBadges.first { $0.type == .verifiedHost }
        let partyGoerBadge = userBadges.first { $0.type == .verifiedPartyGoer }
        
        verificationStatus = UserVerificationStatus(
            isVerifiedHost: hostBadge?.isEarned ?? false,
            isVerifiedPartyGoer: partyGoerBadge?.isEarned ?? false,
            hostBadgeProgress: hostBadge?.progress ?? 0,
            partyGoerBadgeProgress: partyGoerBadge?.progress ?? 0
        )
    }
    
    // MARK: - Notifications
    
    private func showNewBadgeNotification(badge: UserBadge) {
        newlyEarnedBadge = badge
        showingNewBadgeNotification = true
        
        // Auto-hide after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.showingNewBadgeNotification = false
        }
    }
    
    private func showProgressNotification(text: String) {
        progressNotificationText = text
        showingProgressNotification = true
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showingProgressNotification = false
        }
    }
    
    // MARK: - Public Helpers
    
    func getBadgeForUser(userId: String, completion: @escaping (UserVerificationStatus?) -> Void) {
        db.collection("users").document(userId).collection("stats")
            .document("progress")
            .getDocument { snapshot, error in
                guard let data = snapshot?.data() else {
                    completion(nil)
                    return
                }
                
                let partiesHosted = data["partiesHosted"] as? Int ?? 0
                let partiesAttended = data["partiesAttended"] as? Int ?? 0
                
                let status = UserVerificationStatus(
                    isVerifiedHost: partiesHosted >= 4,
                    isVerifiedPartyGoer: partiesAttended >= 4,
                    hostBadgeProgress: partiesHosted,
                    partyGoerBadgeProgress: partiesAttended
                )
                
                completion(status)
            }
    }
    
    func getVerificationBadges() -> [UserBadge] {
        return userBadges.filter { $0.type.isVerificationBadge }
    }
    
    func getProgressBadges() -> [UserBadge] {
        return userBadges.filter { $0.level == .inProgress }
    }
} 