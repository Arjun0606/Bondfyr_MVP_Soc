import Foundation
import FirebaseFirestore
import CoreLocation

// MARK: - Enums for the new marketplace features
enum PartyVisibility: String, CaseIterable, Codable {
    case publicFeed = "public"
    
    var displayName: String {
        switch self {
        case .publicFeed: return "Public (on feed)"
        }
    }
}

enum ApprovalType: String, CaseIterable, Codable {
    case manual = "manual"
    case automatic = "automatic"
    
    var displayName: String {
        switch self {
        case .manual: return "Manual approval"
        case .automatic: return "Auto-approve"
        }
    }
}

enum PaymentStatus: String, Codable {
    case pending = "pending"
    case paid = "paid"
    case refunded = "refunded"
}

// MARK: - Guest request with payment info
struct GuestRequest: Identifiable, Codable {
    let id: String
    let userId: String
    let userName: String
    let userHandle: String
    let introMessage: String
    let requestedAt: Date
    let paymentStatus: PaymentStatus
    let approvalStatus: ApprovalStatus
    let paypalOrderId: String?
    let paidAt: Date?
    let refundedAt: Date?
    let approvedAt: Date?
    
    init(id: String = UUID().uuidString,
         userId: String,
         userName: String,
         userHandle: String,
         introMessage: String,
         requestedAt: Date = Date(),
         paymentStatus: PaymentStatus = .pending,
         approvalStatus: ApprovalStatus = .pending,
         paypalOrderId: String? = nil,
         paidAt: Date? = nil,
         refundedAt: Date? = nil,
         approvedAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.userHandle = userHandle
        self.introMessage = introMessage
        self.requestedAt = requestedAt
        self.paymentStatus = paymentStatus
        self.approvalStatus = approvalStatus
        self.paypalOrderId = paypalOrderId
        self.paidAt = paidAt
        self.refundedAt = refundedAt
        self.approvedAt = approvedAt
    }
}

enum ApprovalStatus: String, Codable {
    case pending = "pending"
    case approved = "approved"
    case denied = "denied"
}

// MARK: - Updated Afterparty model for marketplace
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
    
    // MARK: - New marketplace features
    let title: String
    let ticketPrice: Double // Required - no free parties
    let coverPhotoURL: String?
    let maxGuestCount: Int
    let visibility: PartyVisibility
    let approvalType: ApprovalType
    let ageRestriction: Int? // e.g. 21+ 
    let maxMaleRatio: Double // 0.0 to 1.0, e.g. 0.7 = max 70% male
    let legalDisclaimerAccepted: Bool
    let guestRequests: [GuestRequest] // New detailed guest request system
    let earnings: Double // Host earnings (price * confirmed guests * 0.80)
    let bondfyrFee: Double // 20% fee
    
    // MARK: - TESTFLIGHT: Payment details
    let venmoHandle: String? // Host's Venmo handle for direct payments
    
    // MARK: - Party Chat fields
    let chatEnded: Bool?
    let chatEndedAt: Date?
    
    // MARK: - Computed properties
    var isExpired: Bool {
        return Date() > endTime
    }
    
    var confirmedGuestsCount: Int {
        return activeUsers.count
    }
    
    var pendingGuestsCount: Int {
        return guestRequests.filter { $0.paymentStatus == .pending }.count
    }
    
    // CRITICAL FIX: Add proper count for requests needing host approval
    var pendingApprovalCount: Int {
        return guestRequests.filter { $0.approvalStatus == .pending }.count
    }
    
    var isSoldOut: Bool {
        return confirmedGuestsCount >= maxGuestCount
    }
    
    var currentMaleRatio: Double {
        // This would need actual user gender data - placeholder for now
        return 0.5 // 50% male ratio placeholder
    }
    
    var hostEarnings: Double {
        let confirmedPaidGuests = guestRequests.filter { $0.paymentStatus == .paid }.count
        // TESTFLIGHT: Host keeps 100% during testing phase
        return Double(confirmedPaidGuests) * ticketPrice * 1.0 // 100% to host during TestFlight
    }
    
    var bondfyrRevenue: Double {
        // TESTFLIGHT: No commission during testing phase
        return 0.0 // Full version will be 20% of revenue
        // let confirmedPaidGuests = guestRequests.filter { $0.paymentStatus == .paid }.count
        // return Double(confirmedPaidGuests) * ticketPrice * 0.20
    }
    
    var spotsRemaining: Int {
        return max(0, maxGuestCount - confirmedGuestsCount)
    }
    
    var timeUntilStart: String {
        let now = Date()
        let components = Calendar.current.dateComponents([.hour, .minute], from: now, to: startTime)
        
        if startTime <= now {
            return "Started"
        } else if let hours = components.hour, let minutes = components.minute {
            if hours > 0 {
                return "Starts in \(hours)h \(minutes)m"
            } else {
                return "Starts in \(minutes)m"
            }
        }
        return ""
    }
    
    var shareText: String {
        return "🎉 Join my party '\(title)' at \(locationName)! $\(Int(ticketPrice)) • Starting at \(formatTime(startTime))"
    }
    
    var deepLinkURL: URL {
        return URL(string: "bondfyr://afterparty/\(id)")!
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Updated vibe options for nightlife culture
    static let vibeOptions = [
        "BYOB",
        "Frat", 
        "420",
        "Pool",
        "Rooftop",
        "All-Girls",
        "Dress Code",
        "💊",
        "Lounge",
        "House Party",
        "Dorm Party",
        "Backyard",
        "Exclusive",
        "Games",
        "Dancing",
        "Chill"
    ]
    
    // MARK: - CodingKeys
    private enum CodingKeys: String, CodingKey {
        case id, userId, hostHandle, radius, startTime, endTime
        case city, locationName, description, address, googleMapsLink
        case vibeTag, activeUsers, pendingRequests, createdAt
        case geoPoint, coordinate
        
        // New marketplace fields
        case title, ticketPrice, coverPhotoURL, maxGuestCount
        case visibility, approvalType, ageRestriction, maxMaleRatio
        case legalDisclaimerAccepted, guestRequests, earnings, bondfyrFee
        
        // TESTFLIGHT: Payment details
        case venmoHandle
        
        // Party Chat fields
        case chatEnded, chatEndedAt
    }
    
    // MARK: - Initializer
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
         createdAt: Date = Date(),
         
         // New marketplace parameters
         title: String,
         ticketPrice: Double,
         coverPhotoURL: String? = nil,
         maxGuestCount: Int,
         visibility: PartyVisibility = .publicFeed,
         approvalType: ApprovalType = .manual,
         ageRestriction: Int? = nil,
         maxMaleRatio: Double = 1.0,
         legalDisclaimerAccepted: Bool = false,
         guestRequests: [GuestRequest] = [],
         earnings: Double = 0.0,
         bondfyrFee: Double = 0.20,
         
         // TESTFLIGHT: Payment details
         venmoHandle: String? = nil,
         
         // Party Chat fields
         chatEnded: Bool? = nil,
         chatEndedAt: Date? = nil) {
        
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
        
        // New marketplace fields
        self.title = title
        self.ticketPrice = ticketPrice
        self.coverPhotoURL = coverPhotoURL
        self.maxGuestCount = maxGuestCount
        self.visibility = visibility
        self.approvalType = approvalType
        self.ageRestriction = ageRestriction
        self.maxMaleRatio = maxMaleRatio
        self.legalDisclaimerAccepted = legalDisclaimerAccepted
        self.guestRequests = guestRequests
        self.earnings = earnings
        self.bondfyrFee = bondfyrFee
        
        // TESTFLIGHT: Payment details
        self.venmoHandle = venmoHandle
        
        // Party Chat fields
        self.chatEnded = chatEnded
        self.chatEndedAt = chatEndedAt
    }
    
    // Helper to convert GeoPoint to CLLocationCoordinate2D
    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    // MARK: - Custom Decodable implementation
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
        
        // New marketplace fields with defaults for backward compatibility
        title = (try? container.decode(String.self, forKey: .title)) ?? locationName
        ticketPrice = (try? container.decode(Double.self, forKey: .ticketPrice)) ?? 10.0
        coverPhotoURL = try? container.decode(String.self, forKey: .coverPhotoURL)
        maxGuestCount = (try? container.decode(Int.self, forKey: .maxGuestCount)) ?? 50
        
        // Enums with defaults
        if let visibilityString = try? container.decode(String.self, forKey: .visibility) {
            visibility = PartyVisibility(rawValue: visibilityString) ?? .publicFeed
        } else {
            visibility = .publicFeed
        }
        
        if let approvalString = try? container.decode(String.self, forKey: .approvalType) {
            approvalType = ApprovalType(rawValue: approvalString) ?? .manual
        } else {
            approvalType = .manual
        }
        
        ageRestriction = try? container.decode(Int.self, forKey: .ageRestriction)
        maxMaleRatio = (try? container.decode(Double.self, forKey: .maxMaleRatio)) ?? 1.0
        legalDisclaimerAccepted = (try? container.decode(Bool.self, forKey: .legalDisclaimerAccepted)) ?? false
        guestRequests = (try? container.decode([GuestRequest].self, forKey: .guestRequests)) ?? []
        earnings = (try? container.decode(Double.self, forKey: .earnings)) ?? 0.0
        bondfyrFee = (try? container.decode(Double.self, forKey: .bondfyrFee)) ?? 0.20
        
        // TESTFLIGHT: Payment details
        venmoHandle = try? container.decode(String.self, forKey: .venmoHandle)
        
        // Party Chat fields
        chatEnded = try? container.decode(Bool.self, forKey: .chatEnded)
        if let chatEndTimestamp = try? container.decode(Timestamp.self, forKey: .chatEndedAt) {
            chatEndedAt = chatEndTimestamp.dateValue()
        } else {
            chatEndedAt = try? container.decode(Date.self, forKey: .chatEndedAt)
        }
        
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
    
    // MARK: - Encodable implementation
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
        
        // New marketplace fields
        try container.encode(title, forKey: .title)
        try container.encode(ticketPrice, forKey: .ticketPrice)
        try container.encode(coverPhotoURL, forKey: .coverPhotoURL)
        try container.encode(maxGuestCount, forKey: .maxGuestCount)
        try container.encode(visibility.rawValue, forKey: .visibility)
        try container.encode(approvalType.rawValue, forKey: .approvalType)
        try container.encode(ageRestriction, forKey: .ageRestriction)
        try container.encode(maxMaleRatio, forKey: .maxMaleRatio)
        try container.encode(legalDisclaimerAccepted, forKey: .legalDisclaimerAccepted)
        try container.encode(guestRequests, forKey: .guestRequests)
        try container.encode(earnings, forKey: .earnings)
        try container.encode(bondfyrFee, forKey: .bondfyrFee)
        
        // TESTFLIGHT: Payment details
        try container.encode(venmoHandle, forKey: .venmoHandle)
        
        // Party Chat fields
        try container.encode(chatEnded, forKey: .chatEnded)
        if let chatEndedAt = chatEndedAt {
            try container.encode(Timestamp(date: chatEndedAt), forKey: .chatEndedAt)
        } else {
            try container.encodeNil(forKey: .chatEndedAt)
        }
    }
} 