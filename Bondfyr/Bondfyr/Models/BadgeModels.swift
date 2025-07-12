import Foundation

// MARK: - Simple Achievement System
// Celebrates meaningful milestones instead of complex badge levels

enum AchievementType: String, CaseIterable, Codable {
    case firstPartyHosted = "first_party_hosted"
    case firstPartyAttended = "first_party_attended"
    case hostVerified = "host_verified"
    case guestVerified = "guest_verified"
    case socialConnector = "social_connector"
    case partyMilestone = "party_milestone"
    
    var title: String {
        switch self {
        case .firstPartyHosted:
            return "First Host!"
        case .firstPartyAttended:
            return "Party Goer!"
        case .hostVerified:
            return "Verified Host"
        case .guestVerified:
            return "Verified Guest"
        case .socialConnector:
            return "Social Connector"
        case .partyMilestone:
            return "Party Legend"
        }
    }
    
    var description: String {
        switch self {
        case .firstPartyHosted:
            return "Successfully hosted your first afterparty"
        case .firstPartyAttended:
            return "Attended your first afterparty"
        case .hostVerified:
            return "Verified as a trusted host"
        case .guestVerified:
            return "Verified as an active community member"
        case .socialConnector:
            return "Connected your social media accounts"
        case .partyMilestone:
            return "Reached a major party milestone"
        }
    }
    
    var emoji: String {
        switch self {
        case .firstPartyHosted:
            return "🎉"
        case .firstPartyAttended:
            return "🕺"
        case .hostVerified:
            return "🏆"
        case .guestVerified:
            return "⭐"
        case .socialConnector:
            return "🔗"
        case .partyMilestone:
            return "💎"
        }
    }
}

struct SimpleAchievement: Identifiable, Codable {
    let id: String
    let type: AchievementType
    let title: String
    let description: String
    let emoji: String
    let earnedDate: Date
    let milestone: Int? // For party milestones (5, 10, 25, 50 parties)
    
    init(type: AchievementType, milestone: Int? = nil, earnedDate: Date = Date()) {
        self.id = UUID().uuidString
        self.type = type
        self.title = milestone != nil ? "\(milestone!) \(type.title)" : type.title
        self.description = milestone != nil ? "Reached \(milestone!) parties!" : type.description
        self.emoji = type.emoji
        self.milestone = milestone
        self.earnedDate = earnedDate
    }
    
    var displayTitle: String {
        if let milestone = milestone {
            switch type {
            case .partyMilestone:
                return "\(milestone) Parties"
            default:
                return title
            }
        }
        return title
    }
}

// MARK: - Achievement Progress Tracking
struct AchievementProgress {
    let type: AchievementType
    let current: Int
    let target: Int
    let isCompleted: Bool
    
    var progressPercentage: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }
    
    var progressText: String {
        if isCompleted {
            return "Completed!"
        }
        return "\(current)/\(target)"
    }
} 