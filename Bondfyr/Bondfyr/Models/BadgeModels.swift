import Foundation

enum BadgeType: String, Codable {
    case mostLiked = "Most Liked"
    case topThree = "Top 3"
    case afterpartyHost = "Party Host"
    case afterpartyGuest = "Social Butterfly"
    case dailyStreak = "Daily Streak"
    
    var description: String {
        switch self {
        case .mostLiked:
            return "Get your photos liked by others"
        case .topThree:
            return "Appear in the daily top 3 leaderboard"
        case .afterpartyHost:
            return "Host afterparties for others to join"
        case .afterpartyGuest:
            return "Join and participate in afterparties"
        case .dailyStreak:
            return "Keep your daily photo streak going"
        }
    }
}

enum BadgeLevel: String, Codable {
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"
    
    var color: String {
        switch self {
        case .bronze:
            return "#CD7F32"  // Bronze color
        case .silver:
            return "#C0C0C0"  // Silver color
        case .gold:
            return "#FFD700"  // Gold color
        }
    }
}

struct PhotoBadge: Identifiable, Codable {
    let id: String
    let type: BadgeType
    let name: String
    let description: String
    let imageURL: String
    let earnedDate: Date
    let level: BadgeLevel
    let progress: Double
} 