import Foundation

enum BadgeType: String, Codable, CaseIterable {
    case verifiedHost = "Verified Host"
    case verifiedPartyGoer = "Verified Party Goer"
    case socialStar = "Social Star"
    case partyLegend = "Party Legend"
    case loyalGuest = "Loyal Guest"
    
    var description: String {
        switch self {
        case .verifiedHost:
            return "Successfully hosted 4+ parties"
        case .verifiedPartyGoer:
            return "Attended 4+ parties as a guest"
        case .socialStar:
            return "Get 100+ total likes on photos"
        case .partyLegend:
            return "Host 20+ epic parties"
        case .loyalGuest:
            return "Attend 15+ parties"
        }
    }
    
    var requirement: String {
        switch self {
        case .verifiedHost:
            return "Host 4 parties"
        case .verifiedPartyGoer:
            return "Attend 4 parties"
        case .socialStar:
            return "Get 100 photo likes"
        case .partyLegend:
            return "Host 20 parties"
        case .loyalGuest:
            return "Attend 15 parties"
        }
    }
    
    var perk: String {
        switch self {
        case .verifiedHost:
            return "Priority listing in party feed • Trusted host badge visible to all"
        case .verifiedPartyGoer:
            return "Skip approval for verified hosts • Guest badge visible to all"
        case .socialStar:
            return "Photo highlights in party feeds"
        case .partyLegend:
            return "Legend status visible • Premium host features"
        case .loyalGuest:
            return "Loyalty badge • Early access to new parties"
        }
    }
    
    var emoji: String {
        switch self {
        case .verifiedHost:
            return "👑"
        case .verifiedPartyGoer:
            return "🎊"
        case .socialStar:
            return "⭐"
        case .partyLegend:
            return "🏆"
        case .loyalGuest:
            return "💎"
        }
    }
    
    var isVerificationBadge: Bool {
        return self == .verifiedHost || self == .verifiedPartyGoer
    }
}

enum BadgeLevel: String, Codable {
    case earned = "Earned"
    case inProgress = "In Progress"
    case locked = "Locked"
    
    var color: String {
        switch self {
        case .earned:
            return "#FFD700"  // Gold for earned badges
        case .inProgress:
            return "#FF6B35"  // Orange for in progress
        case .locked:
            return "#6B6B6B"  // Gray for locked
        }
    }
}

struct UserBadge: Identifiable, Codable {
    let id: String
    let type: BadgeType
    let name: String
    let description: String
    let earnedDate: Date?
    let level: BadgeLevel
    let progress: Int // Current count (parties hosted/attended, etc.)
    let requirement: Int // Required count to earn badge
    
    var progressPercentage: Double {
        return min(Double(progress) / Double(requirement), 1.0)
    }
    
    var isEarned: Bool {
        return level == .earned
    }
    
    var progressText: String {
        return "\(progress)/\(requirement) \(type.requirement.lowercased())"
    }
}

// Badge progress for real-time tracking
struct BadgeProgress: Codable {
    let partiesHosted: Int
    let partiesAttended: Int
    let totalPhotoLikes: Int
    
    init(partiesHosted: Int = 0, partiesAttended: Int = 0, totalPhotoLikes: Int = 0) {
        self.partiesHosted = partiesHosted
        self.partiesAttended = partiesAttended
        self.totalPhotoLikes = totalPhotoLikes
    }
}

// User verification status
struct UserVerificationStatus: Codable {
    let isVerifiedHost: Bool
    let isVerifiedPartyGoer: Bool
    let hostBadgeProgress: Int
    let partyGoerBadgeProgress: Int
    
    var hasAnyVerification: Bool {
        return isVerifiedHost || isVerifiedPartyGoer
    }
    
    var verificationText: String {
        if isVerifiedHost && isVerifiedPartyGoer {
            return "Verified Host & Party Goer"
        } else if isVerifiedHost {
            return "Verified Host"
        } else if isVerifiedPartyGoer {
            return "Verified Party Goer"
        } else {
            return "Not Verified"
        }
    }
    
    var verificationEmoji: String {
        if isVerifiedHost && isVerifiedPartyGoer {
            return "👑🎊"
        } else if isVerifiedHost {
            return "👑"
        } else if isVerifiedPartyGoer {
            return "🎊"
        } else {
            return ""
        }
    }
} 