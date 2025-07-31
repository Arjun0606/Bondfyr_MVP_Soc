import Foundation
import FirebaseFirestore

struct PartyRating: Identifiable, Codable {
    let id: String
    let partyId: String
    let userId: String
    let hostId: String
    let rating: Int // 1-5 stars
    let comment: String?
    let submittedAt: Date
    let partyTitle: String
    let hostHandle: String
    
    init(id: String = UUID().uuidString,
         partyId: String,
         userId: String,
         hostId: String,
         rating: Int,
         comment: String? = nil,
         submittedAt: Date = Date(),
         partyTitle: String,
         hostHandle: String) {
        self.id = id
        self.partyId = partyId
        self.userId = userId
        self.hostId = hostId
        self.rating = rating
        self.comment = comment
        self.submittedAt = submittedAt
        self.partyTitle = partyTitle
        self.hostHandle = hostHandle
    }
    
    var isPositiveRating: Bool {
        return rating >= 4
    }
    
    var ratingDescription: String {
        switch rating {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Very Good"
        case 5: return "Excellent"
        default: return "Unknown"
        }
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