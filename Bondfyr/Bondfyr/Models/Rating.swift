import Foundation
import FirebaseFirestore

struct Rating: Identifiable, Codable {
    @DocumentID var id: String?
    var eventId: String
    var raterId: String
    var ratedId: String
    var rating: Double // e.g., 1-5
    var comment: String?
    var timestamp: Timestamp
    
    // To distinguish between rating a host or a guest
    var ratedUserType: String // "host" or "guest"
} 