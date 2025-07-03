import Foundation
import FirebaseFirestore
import FirebaseAuth
import BondfyrPhotos

@MainActor
class BadgeService: ObservableObject {
    static let shared = BadgeService()
    private let db = Firestore.firestore()
    
    @Published var userBadges: [PhotoBadge] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    // Add actual count tracking
    @Published var partyAttendanceCount: Int = 0
    @Published var partyHostedCount: Int = 0
    @Published var totalLikes: Int = 0
    @Published var currentStreak: Int = 0
    @Published var topThreeAppearances: Int = 0
    
    private init() {
        loadUserBadges()
        loadUserStats()
    }
    
    private func loadUserStats() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Load stats from Firestore
        db.collection("users").document(userId).collection("stats")
            .document("counts")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let data = snapshot?.data() else { return }
                
                self.partyAttendanceCount = data["attended"] as? Int ?? 0
                self.partyHostedCount = data["hosted"] as? Int ?? 0
                self.totalLikes = data["totalLikes"] as? Int ?? 0
                self.currentStreak = data["currentStreak"] as? Int ?? 0
                self.topThreeAppearances = data["topThree"] as? Int ?? 0
            }
    }
    
    // Update stats methods
    func incrementPartyAttendance() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        partyAttendanceCount += 1
        
        try? await db.collection("users").document(userId)
            .collection("stats").document("counts")
            .setData(["attended": partyAttendanceCount], merge: true)
        
        await checkAfterpartyGuestBadge(attendedCount: partyAttendanceCount)
    }
    
    func incrementPartyHosted() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        partyHostedCount += 1
        
        try? await db.collection("users").document(userId)
            .collection("stats").document("counts")
            .setData(["hosted": partyHostedCount], merge: true)
        
        await checkAfterpartyHostBadge(hostedCount: partyHostedCount)
    }
    
    func updateTotalLikes(count: Int) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        totalLikes = count
        
        try? await db.collection("users").document(userId)
            .collection("stats").document("counts")
            .setData(["totalLikes": totalLikes], merge: true)
        
        await checkPhotoLikesBadge(totalLikes: totalLikes)
    }
    
    func updateTopThreeAppearances(count: Int) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        topThreeAppearances = count
        
        try? await db.collection("users").document(userId)
            .collection("stats").document("counts")
            .setData(["topThree": topThreeAppearances], merge: true)
        
        await checkTopThreeBadge(appearances: topThreeAppearances)
    }
    
    func updateCurrentStreak(days: Int) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        currentStreak = days
        
        try? await db.collection("users").document(userId)
            .collection("stats").document("counts")
            .setData(["currentStreak": currentStreak], merge: true)
        
        await checkDailyStreakBadge(streakDays: currentStreak)
    }
    
    // MARK: - Badge Loading
    func loadUserBadges() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        
        db.collection("users").document(userId).collection("badges")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.error = error
                    self.isLoading = false
                    return
                }
                
                self.userBadges = snapshot?.documents.compactMap { document in
                    try? document.data(as: PhotoBadge.self)
                } ?? []
                
                self.isLoading = false
            }
    }
    
    // MARK: - Badge Progress Tracking
    
    func checkPhotoLikesBadge(totalLikes: Int) async {
        let badgeType = BadgeType.mostLiked
        let currentLevel = getCurrentBadgeLevel(for: badgeType)
        
        let newLevel: BadgeLevel?
        if totalLikes >= 1000 && currentLevel != .gold {
            newLevel = .gold
        } else if totalLikes >= 500 && currentLevel != .silver {
            newLevel = .silver
        } else if totalLikes >= 100 && currentLevel != .bronze {
            newLevel = .bronze
        } else {
            newLevel = nil
        }
        
        if let level = newLevel {
            await awardBadge(type: badgeType, level: level, progress: calculateProgress(totalLikes, for: badgeType))
        }
    }
    
    func checkTopThreeBadge(appearances: Int) async {
        let badgeType = BadgeType.topThree
        let currentLevel = getCurrentBadgeLevel(for: badgeType)
        
        let newLevel: BadgeLevel?
        if appearances >= 10 && currentLevel != .gold {
            newLevel = .gold
        } else if appearances >= 5 && currentLevel != .silver {
            newLevel = .silver
        } else if appearances >= 1 && currentLevel != .bronze {
            newLevel = .bronze
        } else {
            newLevel = nil
        }
        
        if let level = newLevel {
            await awardBadge(type: badgeType, level: level, progress: calculateProgress(appearances, for: badgeType))
        }
    }
    
    func checkAfterpartyHostBadge(hostedCount: Int) async {
        let badgeType = BadgeType.afterpartyHost
        let currentLevel = getCurrentBadgeLevel(for: badgeType)
        
        let newLevel: BadgeLevel?
        if hostedCount >= 10 && currentLevel != .gold {
            newLevel = .gold
        } else if hostedCount >= 5 && currentLevel != .silver {
            newLevel = .silver
        } else if hostedCount >= 1 && currentLevel != .bronze {
            newLevel = .bronze
        } else {
            newLevel = nil
        }
        
        if let level = newLevel {
            await awardBadge(type: badgeType, level: level, progress: calculateProgress(hostedCount, for: badgeType))
        }
    }
    
    func checkAfterpartyGuestBadge(attendedCount: Int) async {
        let badgeType = BadgeType.afterpartyGuest
        let currentLevel = getCurrentBadgeLevel(for: badgeType)
        
        let newLevel: BadgeLevel?
        if attendedCount >= 20 && currentLevel != .gold {
            newLevel = .gold
        } else if attendedCount >= 10 && currentLevel != .silver {
            newLevel = .silver
        } else if attendedCount >= 3 && currentLevel != .bronze {
            newLevel = .bronze
        } else {
            newLevel = nil
        }
        
        if let level = newLevel {
            await awardBadge(type: badgeType, level: level, progress: calculateProgress(attendedCount, for: badgeType))
        }
    }
    
    func checkDailyStreakBadge(streakDays: Int) async {
        let badgeType = BadgeType.dailyStreak
        let currentLevel = getCurrentBadgeLevel(for: badgeType)
        
        let newLevel: BadgeLevel?
        if streakDays >= 14 && currentLevel != .gold {
            newLevel = .gold
        } else if streakDays >= 7 && currentLevel != .silver {
            newLevel = .silver
        } else if streakDays >= 3 && currentLevel != .bronze {
            newLevel = .bronze
        } else {
            newLevel = nil
        }
        
        if let level = newLevel {
            await awardBadge(type: badgeType, level: level, progress: calculateProgress(streakDays, for: badgeType))
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentBadgeLevel(for type: BadgeType) -> BadgeLevel? {
        return userBadges.first { $0.type == type }?.level
    }
    
    private func calculateProgress(_ value: Int, for type: BadgeType) -> Double {
        switch type {
        case .mostLiked:
            if value >= 1000 { return 1.0 }
            if value >= 500 { return Double(value - 500) / 500.0 }
            if value >= 100 { return Double(value - 100) / 400.0 }
            return Double(value) / 100.0
            
        case .topThree:
            if value >= 10 { return 1.0 }
            if value >= 5 { return Double(value - 5) / 5.0 }
            if value >= 1 { return Double(value - 1) / 4.0 }
            return Double(value)
            
        case .afterpartyHost:
            if value >= 10 { return 1.0 }
            if value >= 5 { return Double(value - 5) / 5.0 }
            if value >= 1 { return Double(value - 1) / 4.0 }
            return Double(value)
            
        case .afterpartyGuest:
            if value >= 20 { return 1.0 }
            if value >= 10 { return Double(value - 10) / 10.0 }
            if value >= 3 { return Double(value - 3) / 7.0 }
            return Double(value) / 3.0
            
        case .dailyStreak:
            if value >= 14 { return 1.0 }
            if value >= 7 { return Double(value - 7) / 7.0 }
            if value >= 3 { return Double(value - 3) / 4.0 }
            return Double(value) / 3.0
        }
    }
    
    private func awardBadge(type: BadgeType, level: BadgeLevel, progress: Double) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let badge = PhotoBadge(
            id: "\(type.rawValue)_\(level.rawValue)".lowercased(),
            type: type,
            name: type.rawValue,
            description: type.description,
            imageURL: getBadgeImageURL(for: type, level: level),
            earnedDate: Date(),
            level: level,
            progress: progress
        )
        
        do {
            try await db.collection("users").document(userId).collection("badges")
                .document(badge.id)
                .setData(from: badge)
            
            // Notify user about new badge
            NotificationCenter.default.post(
                name: Notification.Name("BadgeEarned"),
                object: nil,
                userInfo: ["badge": badge]
            )
        } catch {
            
            self.error = error
        }
    }
    
    private func getBadgeImageURL(for type: BadgeType, level: BadgeLevel) -> String {
        // Generate the badge image
        let image = BadgeEmoji.generateBadgeImage(type: type, level: level)
        
        // Convert to base64 string
        if let imageData = image.pngData() {
            let base64String = imageData.base64EncodedString()
            return "data:image/png;base64,\(base64String)"
        }
        
        // Fallback emoji as URL-safe string
        let fallbackEmoji = BadgeEmoji.getEmoji(for: type, level: level)
        return "data:text/plain;charset=utf-8,\(fallbackEmoji)"
    }
} 