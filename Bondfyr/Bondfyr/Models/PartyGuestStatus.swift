import Foundation
import SwiftUI

// MARK: - Party Guest Status System
// This is the foundation for a flawless guest experience

enum PartyGuestStatus: String, CaseIterable {
    case notRequested = "not_requested"
    case requestSubmitted = "request_submitted" 
    case approved = "approved"
    case denied = "denied"
    case going = "going"                // Fully confirmed, in party chat
    case soldOut = "sold_out"
    case partyEnded = "party_ended"
    
    // MARK: - Display Properties
    var displayText: String {
        switch self {
        case .notRequested: return "Request to Join"
        case .requestSubmitted: return "Request Sent"
        case .approved: return "Approved!"
        case .denied: return "Request Denied"
        case .going: return "You're Going!"
        case .soldOut: return "Sold Out"
        case .partyEnded: return "Party Ended"
        }
    }
    
    var icon: String {
        switch self {
        case .notRequested: return "person.badge.plus"
        case .requestSubmitted: return "clock.arrow.circlepath"
        case .approved: return "bubble.left.and.bubble.right.fill"
        case .denied: return "xmark.circle.fill"
        case .going: return "checkmark.circle.fill"
        case .soldOut: return "exclamationmark.triangle.fill"
        case .partyEnded: return "clock.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .notRequested: return .purple
        case .requestSubmitted: return .orange
        case .approved: return .blue
        case .denied: return .red
        case .going: return .green
        case .soldOut: return .gray
        case .partyEnded: return .gray
        }
    }
    
    var isActionable: Bool {
        switch self {
        case .notRequested, .approved: return true
        default: return false
        }
    }
    
    var showsProgress: Bool {
        return self == .requestSubmitted
    }
}

// MARK: - Party Guest State Manager
class PartyGuestState: ObservableObject {
    @Published var status: PartyGuestStatus = .notRequested
    @Published var lastUpdated: Date = Date()
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    
    private let partyId: String
    private let userId: String
    
    init(partyId: String, userId: String) {
        self.partyId = partyId
        self.userId = userId
    }
    
    // MARK: - Status Calculation
    func calculateStatus(from party: Afterparty, userId: String) -> PartyGuestStatus {
        // Check if party has ended
        if party.endTime < Date() {
            return .partyEnded
        }
        
        // Check if party is at capacity
        if party.activeUsers.count >= party.maxGuestCount {
            return .soldOut
        }
        
        // Check if user is fully confirmed (in activeUsers)
        if party.activeUsers.contains(userId) {
            return .going
        }
        
        // Check guest requests
        if let request = party.guestRequests.first(where: { $0.userId == userId }) {
            switch request.approvalStatus {
            case .pending:
                return .requestSubmitted
            case .approved:
                return .approved  // Approved but not yet in activeUsers
            case .denied:
                return .denied
            }
        }
        
        // Default state
        return .notRequested
    }
    
    // MARK: - State Transitions
    func transitionTo(_ newStatus: PartyGuestStatus) {
        DispatchQueue.main.async {
            self.status = newStatus
            self.lastUpdated = Date()
            self.errorMessage = nil
        }
    }
    
    func setError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.isLoading = false
        }
    }
    
    func setLoading(_ loading: Bool) {
        DispatchQueue.main.async {
            self.isLoading = loading
        }
    }
}

// MARK: - Party Capacity Info
struct PartyCapacityInfo {
    let current: Int
    let maximum: Int
    let percentage: Double
    let isNearCapacity: Bool
    let isFull: Bool
    
    init(current: Int, maximum: Int) {
        self.current = current
        self.maximum = maximum
        self.percentage = maximum > 0 ? Double(current) / Double(maximum) : 0
        self.isNearCapacity = percentage >= 0.8
        self.isFull = current >= maximum
    }
    
    var displayText: String {
        return "\(current)/\(maximum)"
    }
    
    var warningText: String? {
        if isFull {
            return "Party is full"
        } else if isNearCapacity {
            return "Filling up fast!"
        }
        return nil
    }
}

// MARK: - Request Status Tracking
struct RequestStatusInfo {
    let isProcessing: Bool
    let lastAction: Date?
    let expectedResponseTime: TimeInterval
    
    var shouldShowProgress: Bool {
        guard let lastAction = lastAction else { return false }
        return Date().timeIntervalSince(lastAction) < expectedResponseTime
    }
    
    var progressMessage: String {
        if isProcessing {
            return "Processing your request..."
        } else if shouldShowProgress {
            return "Waiting for host response..."
        }
        return ""
    }
} 