import Foundation
import FirebaseFirestore

// MARK: - Party Rating Model
struct PartyRating: Identifiable, Codable {
    let id: String
    let partyId: String
    let partyTitle: String
    let hostId: String
    let hostName: String
    let guestId: String
    let guestName: String
    
    // Ratings (1-5 stars)
    let partyRating: Int        // Overall party experience
    let hostRating: Int         // Host performance
    
    // Optional feedback
    let comments: String?
    
    // Metadata
    let ratedAt: Date
    let partyDate: Date
    
    init(
        id: String = UUID().uuidString,
        partyId: String,
        partyTitle: String,
        hostId: String,
        hostName: String,
        guestId: String,
        guestName: String,
        partyRating: Int,
        hostRating: Int,
        comments: String? = nil,
        ratedAt: Date = Date(),
        partyDate: Date
    ) {
        self.id = id
        self.partyId = partyId
        self.partyTitle = partyTitle
        self.hostId = hostId
        self.hostName = hostName
        self.guestId = guestId
        self.guestName = guestName
        self.partyRating = partyRating
        self.hostRating = hostRating
        self.comments = comments
        self.ratedAt = ratedAt
        self.partyDate = partyDate
    }
}

// MARK: - Host Rating Summary
struct HostRatingSummary: Codable {
    let hostId: String
    let totalRatings: Int
    let averagePartyRating: Double
    let averageHostRating: Double
    let overallAverage: Double
    
    var displayRating: Double {
        return overallAverage
    }
    
    var starRating: Int {
        return Int(round(overallAverage))
    }
}

// MARK: - Party Completion Status
enum PartyCompletionStatus: String, Codable {
    case ongoing = "ongoing"
    case guestEnded = "guest_ended"     // Guest pressed "I'm Done"
    case hostEnded = "host_ended"       // Host ended party
    case autoEnded = "auto_ended"       // System ended (time-based)
}

// MARK: - Party End Action
struct PartyEndAction: Codable {
    let userId: String
    let userName: String
    let action: PartyCompletionStatus
    let timestamp: Date
    
    init(userId: String, userName: String, action: PartyCompletionStatus, timestamp: Date = Date()) {
        self.userId = userId
        self.userName = userName
        self.action = action
        self.timestamp = timestamp
    }
} 