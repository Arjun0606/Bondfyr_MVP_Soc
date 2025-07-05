import Foundation
import FirebaseFirestore

struct ChatMessage: Identifiable, Codable {
    let id: String
    let text: String
    let userHandle: String  // Will be "HOST" or "Guest #X"
    let userId: String
    let timestamp: Date
    let partyId: String
    let isSystemMessage: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case userHandle
        case userId
        case timestamp
        case partyId
        case isSystemMessage
    }
    
    init(id: String = UUID().uuidString,
         text: String,
         userHandle: String,
         userId: String,
         timestamp: Date = Date(),
         partyId: String,
         isSystemMessage: Bool = false) {
        self.id = id
        self.text = text
        self.userHandle = userHandle
        self.userId = userId
        self.timestamp = timestamp
        self.partyId = partyId
        self.isSystemMessage = isSystemMessage
    }
    
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        
        guard let text = data["text"] as? String,
              let userHandle = data["userHandle"] as? String,
              let userId = data["userId"] as? String,
              let partyId = data["partyId"] as? String else {
            return nil
        }
        
        self.id = document.documentID
        self.text = text
        self.userHandle = userHandle
        self.userId = userId
        self.timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        self.partyId = partyId
        self.isSystemMessage = (data["isSystemMessage"] as? Bool) ?? false
    }
} 