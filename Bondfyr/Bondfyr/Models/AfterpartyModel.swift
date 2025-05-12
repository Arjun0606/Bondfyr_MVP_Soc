import Foundation
import FirebaseFirestore
import CoreLocation

struct Afterparty: Identifiable, Codable {
    let id: String
    let userId: String
    let hostHandle: String
    let coordinate: GeoPoint
    let radius: Double
    let startTime: Date
    let endTime: Date
    let city: String
    let locationName: String
    let description: String
    let address: String
    let googleMapsLink: String
    let vibeTag: String
    let activeUsers: [String]
    let pendingRequests: [String]
    let createdAt: Date
    
    var isExpired: Bool {
        return Date() > endTime
    }
    
    var shareText: String {
        return "Join my afterparty at \(locationName)! Starting at \(formatTime(startTime))"
    }
    
    var deepLinkURL: URL {
        return URL(string: "bondfyr://afterparty/\(id)")!
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    static let vibeOptions = [
        "Chill",
        "Lit",
        "Exclusive",
        "Everyone Welcome",
        "Games",
        "Dancing",
        "Drinks",
        "Food"
    ]
    
    // Update CodingKeys to include both possible location field names
    private enum CodingKeys: String, CodingKey {
        case id, userId, hostHandle, radius, startTime, endTime
        case city, locationName, description, address, googleMapsLink
        case vibeTag, activeUsers, pendingRequests, createdAt
        case geoPoint, coordinate
    }
    
    init(id: String = UUID().uuidString,
         userId: String,
         hostHandle: String,
         coordinate: CLLocationCoordinate2D,
         radius: Double,
         startTime: Date,
         endTime: Date,
         city: String,
         locationName: String,
         description: String,
         address: String,
         googleMapsLink: String,
         vibeTag: String,
         activeUsers: [String] = [],
         pendingRequests: [String] = [],
         createdAt: Date = Date()) {
        
        self.id = id
        self.userId = userId
        self.hostHandle = hostHandle
        self.coordinate = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
        self.radius = radius
        self.startTime = startTime
        self.endTime = endTime
        self.city = city
        self.locationName = locationName
        self.description = description
        self.address = address
        self.googleMapsLink = googleMapsLink
        self.vibeTag = vibeTag
        self.activeUsers = activeUsers
        self.pendingRequests = pendingRequests
        self.createdAt = createdAt
    }
    
    // Helper to convert GeoPoint to CLLocationCoordinate2D
    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    // Custom Decodable implementation to handle Firestore types
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Basic fields
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        hostHandle = try container.decode(String.self, forKey: .hostHandle)
        radius = try container.decode(Double.self, forKey: .radius)
        city = try container.decode(String.self, forKey: .city)
        locationName = try container.decode(String.self, forKey: .locationName)
        description = try container.decode(String.self, forKey: .description)
        address = try container.decode(String.self, forKey: .address)
        googleMapsLink = try container.decode(String.self, forKey: .googleMapsLink)
        vibeTag = try container.decode(String.self, forKey: .vibeTag)
        
        // Arrays with default empty if missing
        activeUsers = (try? container.decode([String].self, forKey: .activeUsers)) ?? []
        pendingRequests = (try? container.decode([String].self, forKey: .pendingRequests)) ?? []
        
        // Handle Timestamps
        if let startTimestamp = try? container.decode(Timestamp.self, forKey: .startTime) {
            startTime = startTimestamp.dateValue()
        } else {
            startTime = try container.decode(Date.self, forKey: .startTime)
    }
    
        if let endTimestamp = try? container.decode(Timestamp.self, forKey: .endTime) {
            endTime = endTimestamp.dateValue()
        } else {
            endTime = try container.decode(Date.self, forKey: .endTime)
        }
        
        if let createdTimestamp = try? container.decode(Timestamp.self, forKey: .createdAt) {
            createdAt = createdTimestamp.dateValue()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        // Try to decode location from either geoPoint or coordinate field
        if let geoPoint = try? container.decode(GeoPoint.self, forKey: .geoPoint) {
            coordinate = geoPoint
        } else if let geoPoint = try? container.decode(GeoPoint.self, forKey: .coordinate) {
            coordinate = geoPoint
        } else {
            throw DecodingError.dataCorruptedError(forKey: .geoPoint,
                                                  in: container,
                                                  debugDescription: "Missing or invalid location data")
        }
    }
    
    // Add encode method for Encodable conformance
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(hostHandle, forKey: .hostHandle)
        try container.encode(coordinate, forKey: .coordinate)
        try container.encode(radius, forKey: .radius)
        try container.encode(Timestamp(date: startTime), forKey: .startTime)
        try container.encode(Timestamp(date: endTime), forKey: .endTime)
        try container.encode(city, forKey: .city)
        try container.encode(locationName, forKey: .locationName)
        try container.encode(description, forKey: .description)
        try container.encode(address, forKey: .address)
        try container.encode(googleMapsLink, forKey: .googleMapsLink)
        try container.encode(vibeTag, forKey: .vibeTag)
        try container.encode(activeUsers, forKey: .activeUsers)
        try container.encode(pendingRequests, forKey: .pendingRequests)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
    }
} 