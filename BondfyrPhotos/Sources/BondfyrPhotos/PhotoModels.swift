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

public struct PhotoBadge: Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let imageURL: String
    
    public init(id: String, name: String, description: String, imageURL: String) {
        self.id = id
        self.name = name
        self.description = description
        self.imageURL = imageURL
    }
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