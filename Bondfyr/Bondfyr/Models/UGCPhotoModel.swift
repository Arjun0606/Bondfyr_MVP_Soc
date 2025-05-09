import Foundation
import FirebaseFirestore

public struct UGCPhoto: Identifiable, Codable {
    public var id: String
    public var userId: String
    public var userHandle: String
    public var photoURL: String
    public var city: String
    public var country: String
    public var timestamp: Date
    public var likes: Int
    public var likedBy: [String]
    
    public enum CodingKeys: String, CodingKey {
        case id
        case userId
        case userHandle
        case photoURL
        case city
        case country
        case timestamp
        case likes
        case likedBy
    }
    
    public var isLikedByCurrentUser: Bool {
        guard let currentUserId = UserDefaults.standard.string(forKey: "userId") else { return false }
        return likedBy.contains(currentUserId)
    }
    
    public var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    public var timeRemaining: TimeInterval {
        let expiryTime = timestamp.addingTimeInterval(24 * 3600)
        return max(0, expiryTime.timeIntervalSince(Date()))
    }
    
    public var isExpired: Bool {
        return timeRemaining <= 0
    }
    
    public init(id: String, userId: String, userHandle: String, photoURL: String, city: String, country: String, timestamp: Date, likes: Int, likedBy: [String]) {
        self.id = id
        self.userId = userId
        self.userHandle = userHandle
        self.photoURL = photoURL
        self.city = city
        self.country = country
        self.timestamp = timestamp
        self.likes = likes
        self.likedBy = likedBy
    }
} 