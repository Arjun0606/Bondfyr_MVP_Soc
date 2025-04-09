import Foundation
import FirebaseFirestore

struct ChatMessage: Identifiable, Codable {
    var id: String = UUID().uuidString
    var cityId: String
    var userId: String
    var displayName: String // Anonymous username
    var text: String
    var timestamp: Date
    var isSystemMessage: Bool = false
    var eventId: String? // Optional field for event-specific messages
    
    enum CodingKeys: String, CodingKey {
        case id
        case cityId
        case userId
        case displayName
        case text
        case timestamp
        case isSystemMessage
        case eventId
    }
}

struct ChatCity: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String
    var displayName: String
    var memberCount: Int
    var lastActiveTimestamp: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayName
        case memberCount
        case lastActiveTimestamp
    }
    
    static let mockCities = [
        ChatCity(id: "mumbai", name: "mumbai", displayName: "Mumbai", memberCount: 329, lastActiveTimestamp: Date()),
        ChatCity(id: "delhi", name: "delhi", displayName: "Delhi", memberCount: 204, lastActiveTimestamp: Date()),
        ChatCity(id: "bangalore", name: "bangalore", displayName: "Bangalore", memberCount: 451, lastActiveTimestamp: Date()),
        ChatCity(id: "hyderabad", name: "hyderabad", displayName: "Hyderabad", memberCount: 183, lastActiveTimestamp: Date()),
        ChatCity(id: "pune", name: "pune", displayName: "Pune", memberCount: 176, lastActiveTimestamp: Date()),
        ChatCity(id: "chennai", name: "chennai", displayName: "Chennai", memberCount: 147, lastActiveTimestamp: Date()),
        ChatCity(id: "kolkata", name: "kolkata", displayName: "Kolkata", memberCount: 135, lastActiveTimestamp: Date()),
        ChatCity(id: "ahmedabad", name: "ahmedabad", displayName: "Ahmedabad", memberCount: 112, lastActiveTimestamp: Date()),
        ChatCity(id: "jaipur", name: "jaipur", displayName: "Jaipur", memberCount: 98, lastActiveTimestamp: Date()),
        ChatCity(id: "surat", name: "surat", displayName: "Surat", memberCount: 76, lastActiveTimestamp: Date())
    ]
}

// Helper struct for anonymous username generation
struct UsernameGenerator {
    private static let adjectives = [
        "Dancing", "Neon", "Midnight", "Sparkly", "Cosmic", "Groovy", "Electric", 
        "Mystical", "Funky", "Hypnotic", "Velvet", "Glitter", "Retro", "Jazzy",
        "Vibrant", "Dreamy", "Psychedelic", "Shimmering", "Starlit", "Disco",
        "Melodic", "Ethereal", "Rhythmic", "Luminous", "Radiant", "Pulsing"
    ]
    
    private static let nouns = [
        "Phoenix", "Butterfly", "Tiger", "Dragon", "Unicorn", "Jaguar", "Wolf",
        "Eagle", "Panther", "Raven", "Fox", "Hawk", "Lion", "Falcon", "Bear",
        "Owl", "Cobra", "Leopard", "Lynx", "Dolphin", "Shark", "Viper", 
        "Cheetah", "Scorpion", "Rhino", "Serpent", "Raven", "Moonlight", "Star"
    ]
    
    static func generateUsername() -> String {
        let adjective = adjectives.randomElement() ?? "Mysterious"
        let noun = nouns.randomElement() ?? "Dancer"
        return "\(adjective)\(noun)"
    }
}

struct EventChat: Identifiable, Codable {
    var id: String = UUID().uuidString
    var eventId: String
    var name: String
    var memberCount: Int
    var lastActiveTimestamp: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventId
        case name
        case memberCount
        case lastActiveTimestamp
    }
} 