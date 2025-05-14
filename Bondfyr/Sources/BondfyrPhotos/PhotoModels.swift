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
}

public struct EventPhoto: Identifiable, Codable {
    public let id: String
    public let photoURL: String
    public let userID: String
    public let eventID: String
    public let timestamp: Date
    public let likes: Int
}

public struct PhotoBadge: Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let imageURL: String
}

public enum PhotoScope: String, CaseIterable {
    case city = "City"
    case daily = "Daily"
    case event = "Event"
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