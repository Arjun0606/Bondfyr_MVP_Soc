import Foundation
import FirebaseFirestore

struct CheckIn: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var eventId: String
    var timestamp: Date
    var ticketId: String
    var isActive: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case eventId
        case timestamp
        case ticketId
        case isActive
    }
} 