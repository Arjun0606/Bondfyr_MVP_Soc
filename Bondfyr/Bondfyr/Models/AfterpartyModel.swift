import Foundation
import FirebaseFirestore
import CoreLocation

// MARK: - Enums for the new marketplace features
enum PartyVisibility: String, CaseIterable, Codable {
    case publicFeed = "public"
    case unlisted = "unlisted"
    
    var displayName: String {
        switch self {
        case .publicFeed: return "Public (on feed)"
        case .unlisted: return "Unlisted (link-only)"
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
    case proofSubmitted = "proof_submitted" // NEW: Guest uploaded proof, awaiting host verification
    case paid = "paid"
    case free = "free" // NEW: VIP/complimentary entry, no payment required
    case refunded = "refunded"
}

// MARK: - Guest request with payment info
struct GuestRequest: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let userName: String
    let userHandle: String
    let introMessage: String
    let requestedAt: Date
    let paymentStatus: PaymentStatus
    let approvalStatus: ApprovalStatus
    let paypalOrderId: String?
    let dodoPaymentIntentId: String?
    let paidAt: Date?
    let refundedAt: Date?
    let approvedAt: Date?
    
    // NEW: P2P Payment Proof Fields
    let paymentProofImageURL: String? // URL to uploaded payment screenshot
    let proofSubmittedAt: Date? // When guest submitted proof
    let verificationImageURL: String? // URL to guest's ID/verification photo
    
    init(id: String = UUID().uuidString,
         userId: String,
         userName: String,
         userHandle: String,
         introMessage: String,
         requestedAt: Date = Date(),
         paymentStatus: PaymentStatus = .pending,
         approvalStatus: ApprovalStatus = .pending,
         paypalOrderId: String? = nil,
         dodoPaymentIntentId: String? = nil,
         paidAt: Date? = nil,
         refundedAt: Date? = nil,
         approvedAt: Date? = nil,
         paymentProofImageURL: String? = nil,
         proofSubmittedAt: Date? = nil,
         verificationImageURL: String? = nil) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.userHandle = userHandle
        self.introMessage = introMessage
        self.requestedAt = requestedAt
        self.paymentStatus = paymentStatus
        self.approvalStatus = approvalStatus
        self.paypalOrderId = paypalOrderId
        self.dodoPaymentIntentId = dodoPaymentIntentId
        self.paidAt = paidAt
        self.refundedAt = refundedAt
        self.approvedAt = approvedAt
        self.paymentProofImageURL = paymentProofImageURL
        self.proofSubmittedAt = proofSubmittedAt
        self.verificationImageURL = verificationImageURL
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
    
    // MARK: - Host Profile Information
    let phoneNumber: String? // Host's phone number for guest contact
    let instagramHandle: String? // Host's Instagram handle
    let snapchatHandle: String? // Host's Snapchat handle
    
    // MARK: - Payment Methods (Critical for P2P payments)
    let venmoHandle: String? // Host's Venmo handle (@username)
    let zelleInfo: String? // Host's Zelle phone/email
    let cashAppHandle: String? // Host's Cash App handle ($username)
    let acceptsApplePay: Bool? // Whether host accepts Apple Pay via phone
    let collectInPerson: Bool? // If true, host collects IRL; hide P2P flow
    
    // MARK: - Dodo Payment Integration (for listing fees)
    let paymentId: String? // Dodo payment ID for listing fee
    let paymentStatus: String? // Dodo payment status
    let listingFeePaid: Bool? // Whether listing fee was paid
    
    // MARK: - Stats Processing (Realistic Metrics System)
    let statsProcessed: Bool?        // Whether user stats have been updated
    let statsProcessedAt: Date?      // When stats were processed
    
    // MARK: - Rating and Party Completion System
    let completionStatus: PartyCompletionStatus?  // How the party ended
    let endedAt: Date?                            // When party was marked as ended
    let endedBy: String?                          // User ID who ended the party
    let ratedBy: [String: Bool]?                  // Track which guests have rated
    let lastRatedAt: Date?                        // When last rating was submitted
    
    // MARK: - Enhanced Rating System for Host Reputation
    let ratingsSubmitted: [String: Int]?          // userId: rating (1-5 stars)
    let ratingsRequired: Int?                     // Total checked-in guests who can rate
    let hostCreditAwarded: Bool?                  // Prevent duplicate host credits
    let averageRating: Double?                    // Calculated average of all ratings
    let totalRatingsCount: Int?                   // Total number of ratings received
    
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
        // Updated to 80% commission (20% platform fee)
        return Double(confirmedPaidGuests) * ticketPrice * 0.80 // 80% to host
    }
    
    var bondfyrRevenue: Double {
        // Updated to 20% commission
        let confirmedPaidGuests = guestRequests.filter { $0.paymentStatus == .paid }.count
        return Double(confirmedPaidGuests) * ticketPrice * 0.20 // 20% platform fee
    }
    
    var spotsRemaining: Int {
        return max(0, maxGuestCount - confirmedGuestsCount)
    }
    
    var isEnded: Bool {
        return completionStatus != nil && completionStatus != .ongoing
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
        "House Party",
        "💊", 
        "420",
        "Dorm",
        "Pre Game"
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
        
        // Host Profile Information
        case phoneNumber, instagramHandle, snapchatHandle
        
        // Payment Methods (Critical for P2P payments)
        case venmoHandle, zelleInfo, cashAppHandle, acceptsApplePay, collectInPerson
        
        // Dodo Payment Integration (for listing fees)
        case paymentId, paymentStatus, listingFeePaid
        case hostId, partyId // Legacy/duplicate fields
        
        // Party Chat fields

        
        // Stats Processing (Realistic Metrics System)
        case statsProcessed, statsProcessedAt
        
        // Rating and Party Completion System
        case completionStatus, endedAt, endedBy, ratedBy, lastRatedAt
        
        // Enhanced Rating System for Host Reputation
        case ratingsSubmitted, ratingsRequired, hostCreditAwarded, averageRating, totalRatingsCount
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
         
         // Host Profile Information
         phoneNumber: String? = nil,
         instagramHandle: String? = nil,
         snapchatHandle: String? = nil,
         
         // Payment Methods (Critical for P2P payments)
         venmoHandle: String? = nil,
         zelleInfo: String? = nil,
         cashAppHandle: String? = nil,
          acceptsApplePay: Bool? = nil,
          collectInPerson: Bool? = nil,
         
         // Dodo Payment Integration (for listing fees)
         paymentId: String? = nil,
         paymentStatus: String? = nil,
         listingFeePaid: Bool? = nil,
         
         // Party Chat fields
         
         
         // Stats Processing (Realistic Metrics System)
         statsProcessed: Bool? = nil,
         statsProcessedAt: Date? = nil,
         
         // Rating and Party Completion System
         completionStatus: PartyCompletionStatus? = nil,
         endedAt: Date? = nil,
         endedBy: String? = nil,
         ratedBy: [String: Bool]? = nil,
         lastRatedAt: Date? = nil,
         
         // Enhanced Rating System for Host Reputation
         ratingsSubmitted: [String: Int]? = nil,
         ratingsRequired: Int? = nil,
         hostCreditAwarded: Bool? = nil,
         averageRating: Double? = nil,
         totalRatingsCount: Int? = nil) {
        
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
        
        // Host Profile Information
        self.phoneNumber = phoneNumber
        self.instagramHandle = instagramHandle
        self.snapchatHandle = snapchatHandle
        
        // Payment Methods (Critical for P2P payments)
        self.venmoHandle = venmoHandle
        self.zelleInfo = zelleInfo
        self.cashAppHandle = cashAppHandle
        self.acceptsApplePay = acceptsApplePay
        self.collectInPerson = collectInPerson
        
        // Dodo Payment Integration (for listing fees)
        self.paymentId = paymentId
        self.paymentStatus = paymentStatus
        self.listingFeePaid = listingFeePaid
        
        // Party Chat fields

        
        // Stats Processing (Realistic Metrics System)
        self.statsProcessed = statsProcessed
        self.statsProcessedAt = statsProcessedAt
        
        // Rating and Party Completion System
        self.completionStatus = completionStatus
        self.endedAt = endedAt
        self.endedBy = endedBy
        self.ratedBy = ratedBy
        self.lastRatedAt = lastRatedAt
        
        // Enhanced Rating System for Host Reputation
        self.ratingsSubmitted = ratingsSubmitted
        self.ratingsRequired = ratingsRequired
        self.hostCreditAwarded = hostCreditAwarded
        self.averageRating = averageRating
        self.totalRatingsCount = totalRatingsCount
    }
    
    // Helper to convert GeoPoint to CLLocationCoordinate2D
    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    // MARK: - Custom Decodable implementation
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Basic fields
        id = try container.decode(String.self, forKey: .partyId)
        userId = try container.decode(String.self, forKey: .userId)
        hostHandle = try container.decode(String.self, forKey: .hostHandle)
        radius = try container.decode(Double.self, forKey: .radius)
        city = try container.decode(String.self, forKey: .city)
        locationName = try container.decode(String.self, forKey: .locationName)
        description = try container.decode(String.self, forKey: .description)
        address = try container.decode(String.self, forKey: .address)
        googleMapsLink = (try? container.decode(String.self, forKey: .googleMapsLink)) ?? ""
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
        
        // Host Profile Information
        phoneNumber = try? container.decode(String.self, forKey: .phoneNumber)
        instagramHandle = try? container.decode(String.self, forKey: .instagramHandle)
        snapchatHandle = try? container.decode(String.self, forKey: .snapchatHandle)
        
        // Payment Methods (Critical for P2P payments) - FIXED DECODER
        venmoHandle = try? container.decode(String.self, forKey: .venmoHandle)
        zelleInfo = try? container.decode(String.self, forKey: .zelleInfo)
        cashAppHandle = try? container.decode(String.self, forKey: .cashAppHandle)
        acceptsApplePay = (try? container.decode(Bool.self, forKey: .acceptsApplePay)) ?? false
        collectInPerson = (try? container.decode(Bool.self, forKey: .collectInPerson)) ?? false
        
        // Dodo Payment Integration (for listing fees) - FIXED DECODER
        paymentId = try? container.decode(String.self, forKey: .paymentId)
        paymentStatus = try? container.decode(String.self, forKey: .paymentStatus)
        listingFeePaid = (try? container.decode(Bool.self, forKey: .listingFeePaid)) ?? false
        
        // Party Chat fields

        
        // Stats Processing (Realistic Metrics System)
        statsProcessed = try? container.decode(Bool.self, forKey: .statsProcessed)
        if let statsProcessedTimestamp = try? container.decode(Timestamp.self, forKey: .statsProcessedAt) {
            statsProcessedAt = statsProcessedTimestamp.dateValue()
        } else {
            statsProcessedAt = try? container.decode(Date.self, forKey: .statsProcessedAt)
        }
        
        // Rating and Party Completion System
        completionStatus = try? container.decode(PartyCompletionStatus.self, forKey: .completionStatus)
        if let endedAtTimestamp = try? container.decode(Timestamp.self, forKey: .endedAt) {
            endedAt = endedAtTimestamp.dateValue()
        } else {
            endedAt = try? container.decode(Date.self, forKey: .endedAt)
        }
        endedBy = try? container.decode(String.self, forKey: .endedBy)
        ratedBy = (try? container.decode([String: Bool].self, forKey: .ratedBy)) ?? [:]
        if let lastRatedAtTimestamp = try? container.decode(Timestamp.self, forKey: .lastRatedAt) {
            lastRatedAt = lastRatedAtTimestamp.dateValue()
        } else {
            lastRatedAt = try? container.decode(Date.self, forKey: .lastRatedAt)
        }
        
        // Enhanced Rating System for Host Reputation
        ratingsSubmitted = (try? container.decode([String: Int].self, forKey: .ratingsSubmitted)) ?? [:]
        ratingsRequired = try? container.decode(Int.self, forKey: .ratingsRequired)
        hostCreditAwarded = (try? container.decode(Bool.self, forKey: .hostCreditAwarded)) ?? false
        averageRating = (try? container.decode(Double.self, forKey: .averageRating)) ?? 0.0
        totalRatingsCount = (try? container.decode(Int.self, forKey: .totalRatingsCount)) ?? 0
        
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
            // Try to decode as nested container for dictionary format
            do {
                let coordinateContainer = try container.nestedContainer(keyedBy: CoordinateKeys.self, forKey: .coordinate)
                
                // Try to decode as strings first, then as doubles
                if let latString = try? coordinateContainer.decode(String.self, forKey: .latitude),
                   let lonString = try? coordinateContainer.decode(String.self, forKey: .longitude),
                   let lat = Double(latString),
                   let lon = Double(lonString) {
                    coordinate = GeoPoint(latitude: lat, longitude: lon)
                } else {
                    let lat = try coordinateContainer.decode(Double.self, forKey: .latitude)
                    let lon = try coordinateContainer.decode(Double.self, forKey: .longitude)
                    coordinate = GeoPoint(latitude: lat, longitude: lon)
                }
            } catch {
                throw DecodingError.dataCorruptedError(forKey: .coordinate,
                                                  in: container,
                                                      debugDescription: "Missing or invalid location data: \(error)")
        }
        }
        
    }
    
    // Helper CodingKeys for coordinate dictionary
    private enum CoordinateKeys: String, CodingKey {
        case latitude, longitude
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
        
        // Encode payment methods and collection mode
        try container.encode(venmoHandle, forKey: .venmoHandle)
        try container.encode(zelleInfo, forKey: .zelleInfo)
        try container.encode(cashAppHandle, forKey: .cashAppHandle)
        try container.encode(acceptsApplePay, forKey: .acceptsApplePay)
        try container.encode(collectInPerson ?? false, forKey: .collectInPerson)
        
        // Party Chat fields

        
        // Stats Processing (Realistic Metrics System)
        try container.encode(statsProcessed, forKey: .statsProcessed)
        if let statsProcessedAt = statsProcessedAt {
            try container.encode(Timestamp(date: statsProcessedAt), forKey: .statsProcessedAt)
        } else {
            try container.encodeNil(forKey: .statsProcessedAt)
        }
        
        // Rating and Party Completion System
        try container.encode(completionStatus, forKey: .completionStatus)
        if let endedAt = endedAt {
            try container.encode(Timestamp(date: endedAt), forKey: .endedAt)
        } else {
            try container.encodeNil(forKey: .endedAt)
        }
        try container.encode(endedBy, forKey: .endedBy)
        try container.encode(ratedBy, forKey: .ratedBy)
        if let lastRatedAt = lastRatedAt {
            try container.encode(Timestamp(date: lastRatedAt), forKey: .lastRatedAt)
        } else {
            try container.encodeNil(forKey: .lastRatedAt)
        }
        
        // Enhanced Rating System for Host Reputation
        try container.encode(ratingsSubmitted, forKey: .ratingsSubmitted)
        try container.encode(ratingsRequired, forKey: .ratingsRequired)
        try container.encode(hostCreditAwarded, forKey: .hostCreditAwarded)
        try container.encode(averageRating, forKey: .averageRating)
        try container.encode(totalRatingsCount, forKey: .totalRatingsCount)
    }
} 

// MARK: - Sample Data for Previews
extension Afterparty {
    static var sampleData: Afterparty {
        Afterparty(
            userId: "sample-host-id",
            hostHandle: "@samplehost",
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            radius: 1000,
            startTime: Date().addingTimeInterval(3600), // 1 hour from now
            endTime: Date().addingTimeInterval(25200), // 7 hours from now
            city: "San Francisco",
            locationName: "Sample Venue",
            description: "A sample party for previews and testing",
            address: "123 Sample Street, San Francisco, CA",
            googleMapsLink: "https://maps.google.com",
            vibeTag: "House Party, BYOB",
            activeUsers: ["user1", "user2", "user3", "user4", "user5"],
            createdAt: Date(),
            title: "Epic Sample Party",
            ticketPrice: 15.0,
            maxGuestCount: 25,
            guestRequests: [
                GuestRequest(
                    userId: "guest1",
                    userName: "Sample Guest",
                    userHandle: "@sampleguest",
                    introMessage: "Looking forward to the party!",
                    paymentStatus: .paid,
                    approvalStatus: .approved
                )
            ]
        )
    }
} 