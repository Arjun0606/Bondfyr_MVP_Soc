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
    
    // Enhanced features
    let messageType: MessageType
    let imageURL: String?
    let imageAspectRatio: Double?
    let replyToMessageId: String?
    let replyToText: String?
    let replyToUserHandle: String?
    var reactions: [String: [String]] // emoji -> [userIds]
    let isEdited: Bool
    let editedAt: Date?
    
    enum MessageType: String, Codable {
        case text
        case image
        case system
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case userHandle
        case userId
        case timestamp
        case partyId
        case isSystemMessage
        case messageType
        case imageURL
        case imageAspectRatio
        case replyToMessageId
        case replyToText
        case replyToUserHandle
        case reactions
        case isEdited
        case editedAt
    }
    
    init(id: String = UUID().uuidString,
         text: String,
         userHandle: String,
         userId: String,
         timestamp: Date = Date(),
         partyId: String,
         isSystemMessage: Bool = false,
         messageType: MessageType = .text,
         imageURL: String? = nil,
         imageAspectRatio: Double? = nil,
         replyToMessageId: String? = nil,
         replyToText: String? = nil,
         replyToUserHandle: String? = nil,
         reactions: [String: [String]] = [:],
         isEdited: Bool = false,
         editedAt: Date? = nil) {
        self.id = id
        self.text = text
        self.userHandle = userHandle
        self.userId = userId
        self.timestamp = timestamp
        self.partyId = partyId
        self.isSystemMessage = isSystemMessage
        self.messageType = messageType
        self.imageURL = imageURL
        self.imageAspectRatio = imageAspectRatio
        self.replyToMessageId = replyToMessageId
        self.replyToText = replyToText
        self.replyToUserHandle = replyToUserHandle
        self.reactions = reactions
        self.isEdited = isEdited
        self.editedAt = editedAt
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
        
        // Enhanced features
        let messageTypeString = data["messageType"] as? String ?? "text"
        self.messageType = MessageType(rawValue: messageTypeString) ?? .text
        self.imageURL = data["imageURL"] as? String
        self.imageAspectRatio = data["imageAspectRatio"] as? Double
        self.replyToMessageId = data["replyToMessageId"] as? String
        self.replyToText = data["replyToText"] as? String
        self.replyToUserHandle = data["replyToUserHandle"] as? String
        self.reactions = data["reactions"] as? [String: [String]] ?? [:]
        self.isEdited = data["isEdited"] as? Bool ?? false
        self.editedAt = (data["editedAt"] as? Timestamp)?.dateValue()
    }
} 