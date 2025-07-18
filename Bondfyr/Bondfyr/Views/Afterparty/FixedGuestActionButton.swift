import SwiftUI
import FirebaseAuth

/// FIXED GUEST ACTION BUTTON - Properly handles payment flow
struct FixedGuestActionButton: View {
    let afterparty: Afterparty
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingContactHost = false
    @State private var showingPaymentSheet = false
    @State private var showingShareSheet = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Main guest action button
            guestActionButton
            
            // Share button
            Button(action: { showingShareSheet = true }) {
                Image(systemName: "square.and.arrow.up")
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showingContactHost) {
            RequestToJoinSheet(afterparty: afterparty) {
                // Refresh party data after request submission
                refreshAfterpartyData()
            }
        }
        .sheet(isPresented: $showingPaymentSheet) {
            DodoPaymentSheet(afterparty: afterparty) {
                // Refresh party data after payment completion
                refreshAfterpartyData()
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            SocialShareSheet(party: afterparty, isPresented: $showingShareSheet)
        }
        .alert("Notice", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Guest Action Button (FIXED)
    
    private var guestActionButton: some View {
        let currentUserId = authViewModel.currentUser?.uid ?? ""
        let buttonState = determineGuestButtonState(userId: currentUserId)
        
        return Button(action: {
            handleGuestAction(state: buttonState, userId: currentUserId)
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    buttonContent(for: buttonState)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(buttonBackground(for: buttonState))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isLoading || !buttonState.isEnabled)
    }
    
    // MARK: - Button State Logic (FIXED)
    
    private enum GuestButtonState {
        case requestToJoin
        case pending
        case approved // NEW: Approved but payment pending
        case going
        case denied
        case soldOut
        
        var isEnabled: Bool {
            switch self {
            case .requestToJoin, .approved: return true
            case .pending, .going, .denied, .soldOut: return false
            }
        }
    }
    
    private func determineGuestButtonState(userId: String) -> GuestButtonState {
        // CRITICAL FIX: Use the most recent party data from the manager
        let currentAfterparty = afterpartyManager.nearbyAfterparties.first { $0.id == afterparty.id } ?? afterparty
        
        print("🔍 FIXED BUTTON: Determining button state for user \(userId)")
        print("🔍 FIXED BUTTON: activeUsers: \(currentAfterparty.activeUsers)")
        print("🔍 FIXED BUTTON: guestRequests count: \(currentAfterparty.guestRequests.count)")
        
        // Check if fully confirmed (in activeUsers)
        if currentAfterparty.activeUsers.contains(userId) {
            print("🔍 FIXED BUTTON: User is in activeUsers - state: going")
            return .going
        }
        
        // Check if party is sold out
        if currentAfterparty.activeUsers.count >= currentAfterparty.maxGuestCount {
            print("🔍 FIXED BUTTON: Party is sold out - state: soldOut")
            return .soldOut
        }
        
        // Check guest requests using fresh data
        if let request = currentAfterparty.guestRequests.first(where: { $0.userId == userId }) {
            print("🔍 FIXED BUTTON: Found request - approval: \(request.approvalStatus), payment: \(request.paymentStatus)")
            
            switch request.approvalStatus {
            case .pending:
                print("🔍 FIXED BUTTON: Request pending - state: pending")
                return .pending
            case .approved:
                // CRITICAL FIX: Check if they're in activeUsers (paid) or not
                if currentAfterparty.activeUsers.contains(userId) {
                    print("🔍 FIXED BUTTON: Approved and paid - state: going")
                    return .going
                } else {
                    print("🔍 FIXED BUTTON: Approved but not paid - state: approved")
                    return .approved // Need to pay!
                }
            case .denied:
                print("🔍 FIXED BUTTON: Request denied - state: denied")
                return .denied
            }
        }
        
        print("🔍 FIXED BUTTON: No request found - state: requestToJoin")
        return .requestToJoin
    }
    
    @ViewBuilder
    private func buttonContent(for state: GuestButtonState) -> some View {
        switch state {
        case .requestToJoin:
            Image(systemName: "person.badge.plus")
            Text("Request to Join ($\(Int(afterparty.ticketPrice)))")
        case .pending:
            Image(systemName: "clock.fill")
            Text("Pending")
        case .approved:
            Image(systemName: "creditcard.fill")
            Text("Complete Payment ($\(Int(afterparty.ticketPrice)))")
        case .going:
            Image(systemName: "checkmark.circle.fill")
            Text("Going")
        case .denied:
            Image(systemName: "xmark.circle.fill")
            Text("Request Denied")
        case .soldOut:
            Image(systemName: "xmark.circle.fill")
            Text("Sold Out")
        }
    }
    
    private func buttonBackground(for state: GuestButtonState) -> AnyView {
        switch state {
        case .requestToJoin:
            return AnyView(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
        case .pending:
            return AnyView(Color.orange)
        case .approved:
            return AnyView(Color.blue) // Blue for payment required
        case .going:
            return AnyView(Color.green)
        case .denied, .soldOut:
            return AnyView(Color.gray)
        }
    }
    
    // MARK: - Action Handling (FIXED)
    
    private func handleGuestAction(state: GuestButtonState, userId: String) {
        print("🔍 FIXED BUTTON: Handling guest action for state: \(state)")
        
        switch state {
        case .requestToJoin:
            print("🔍 FIXED BUTTON: Opening request sheet")
            showingContactHost = true
            
        case .approved:
            print("🔍 FIXED BUTTON: Opening payment sheet - user is approved!")
            showingPaymentSheet = true
            
        default:
            print("🔍 FIXED BUTTON: No action for state: \(state)")
            break
        }
    }
    
    // MARK: - Data Refresh
    
    private func refreshAfterpartyData() {
        print("🔄 FIXED BUTTON: Refreshing afterparty data")
        Task {
            do {
                let updatedParty = try await afterpartyManager.getAfterpartyById(afterparty.id)
                // Note: This will trigger a view update in the parent component
                print("🔄 FIXED BUTTON: Data refreshed successfully")
            } catch {
                print("🔴 FIXED BUTTON: Error refreshing data: \(error)")
            }
        }
    }
}

// MARK: - Preview
struct FixedGuestActionButton_Previews: PreviewProvider {
    static var previews: some View {
        FixedGuestActionButton(afterparty: Afterparty.preview)
            .environmentObject(AuthViewModel())
            .padding()
            .background(Color.black)
    }
}

// MARK: - Preview Data Extension
extension Afterparty {
    static var preview: Afterparty {
        Afterparty(
            userId: "host123",
            hostHandle: "@testhost",
            coordinate: .init(latitude: 37.7749, longitude: -122.4194),
            radius: 1000,
            startTime: Date().addingTimeInterval(3600),
            endTime: Date().addingTimeInterval(7200),
            city: "San Francisco",
            locationName: "Test Venue",
            description: "Test party",
            address: "123 Test St",
            googleMapsLink: "",
            vibeTag: "🎉",
            title: "Test Party",
            ticketPrice: 10,
            maxGuestCount: 25
        )
    }
} 