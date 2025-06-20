import Foundation

// MARK: - Models
public struct CityPhoto: Identifiable, Codable {
    public let id: String
    public var imageUrl: String
    public let city: String
    public let timestamp: Date
    public var likes: Int
    public let expiresAt: Date
    
    public var isExpired: Bool {
        Date() > expiresAt
    }
    
    public init(id: String, imageUrl: String, city: String, timestamp: Date, likes: Int, expiresAt: Date) {
        self.id = id
        self.imageUrl = imageUrl
        self.city = city
        self.timestamp = timestamp
        self.likes = likes
        self.expiresAt = expiresAt
    }
}

public struct DailyPhoto: Identifiable, Codable {
    public let id: String
    public let photoURL: String
    public let userID: String
    public let userHandle: String
    public let city: String
    public let country: String
    public let timestamp: Date
    public let likes: Int
    public let likedBy: [String]
    
    public init(id: String, photoURL: String, userID: String, userHandle: String, city: String, country: String, timestamp: Date, likes: Int, likedBy: [String]) {
        self.id = id
        self.photoURL = photoURL
        self.userID = userID
        self.userHandle = userHandle
        self.city = city
        self.country = country
        self.timestamp = timestamp
        self.likes = likes
        self.likedBy = likedBy
    }
}

public struct EventPhoto: Identifiable, Codable {
    public let id: String
    public let photoURL: String
    public let userID: String
    public let eventID: String
    public let timestamp: Date
    public let likes: Int
    
    public init(id: String, photoURL: String, userID: String, eventID: String, timestamp: Date, likes: Int) {
        self.id = id
        self.photoURL = photoURL
        self.userID = userID
        self.eventID = eventID
        self.timestamp = timestamp
        self.likes = likes
    }
}

public struct PhotoBadge: Identifiable, Codable {
    public let id: String
    public let type: BadgeType
    public let name: String
    public let description: String
    public let imageURL: String
    public let earnedDate: Date
    public let level: BadgeLevel
    public let progress: Double // 0.0 to 1.0 for progress towards next level
    
    public init(id: String, type: BadgeType, name: String, description: String, imageURL: String, earnedDate: Date, level: BadgeLevel, progress: Double) {
        self.id = id
        self.type = type
        self.name = name
        self.description = description
        self.imageURL = imageURL
        self.earnedDate = earnedDate
        self.level = level
        self.progress = progress
    }
}

public enum BadgeType: String, Codable, CaseIterable {
    case mostLiked = "Most Liked"
    case topThree = "Top 3"
    case afterpartyHost = "Party Host"
    case afterpartyGuest = "Social Butterfly"
    case dailyStreak = "Daily Streak"
    
    public var description: String {
        switch self {
        case .mostLiked:
            return "Photos reached total like milestones"
        case .topThree:
            return "Consistently in the top 3 of the leaderboard"
        case .afterpartyHost:
            return "Hosting successful afterparties"
        case .afterpartyGuest:
            return "Attending afterparties"
        case .dailyStreak:
            return "Consecutive days of activity"
        }
    }
    
    public var criteria: String {
        switch self {
        case .mostLiked:
            return "Bronze: 100 likes\nSilver: 500 likes\nGold: 1000 likes"
        case .topThree:
            return "Bronze: Top 3 once\nSilver: Top 3 five times\nGold: Top 3 ten times"
        case .afterpartyHost:
            return "Bronze: Host 1 party\nSilver: Host 5 parties\nGold: Host 10 parties"
        case .afterpartyGuest:
            return "Bronze: Attend 3 parties\nSilver: Attend 10 parties\nGold: Attend 20 parties"
        case .dailyStreak:
            return "Bronze: 3 day streak\nSilver: 7 day streak\nGold: 14 day streak"
        }
    }
}

public enum BadgeLevel: String, Codable, CaseIterable {
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"
    
    public var color: String {
        switch self {
        case .bronze:
            return "#CD7F32"
        case .silver:
            return "#C0C0C0"
        case .gold:
            return "#FFD700"
        }
    }
}

public enum PhotoScope: String, CaseIterable {
    case today = "Leaderboard Today"
    case cumulative = "Leaderboard Cumulative"
}

public enum PhotoError: Error {
    case imageCompressionFailed
    case uploadFailed
    case downloadFailed
    case invalidData
    case invalidScope
    case invalidImageData
    case userNotAuthenticated
} 