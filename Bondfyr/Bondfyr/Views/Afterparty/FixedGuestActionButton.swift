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
        .onAppear {
            print("🔵 GUEST BUTTON: onAppear - forcing data refresh")
            refreshAfterpartyData()
            
            // Listen for guest approval notifications
            NotificationCenter.default.addObserver(
                forName: Notification.Name("GuestApproved"),
                object: nil,
                queue: .main
            ) { _ in
                print("🔔 GUEST BUTTON: Received guest approval notification - refreshing")
                refreshAfterpartyData()
            }
            
            // Listen for payment completion notifications
            NotificationCenter.default.addObserver(
                forName: Notification.Name("PaymentCompleted"),
                object: nil,
                queue: .main
            ) { notification in
                print("🔔 GUEST BUTTON: Received payment completion notification - refreshing")
                // Check if this notification is for our party
                let notificationPartyId = notification.object as? String ?? notification.userInfo?["partyId"] as? String
                if let partyId = notificationPartyId, partyId == afterparty.id {
                    print("🔔 GUEST BUTTON: Notification is for our party - refreshing data")
                    refreshAfterpartyData()
                } else {
                    print("🔔 GUEST BUTTON: Notification is for different party or no party ID - refreshing anyway")
                    refreshAfterpartyData()
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: Notification.Name("GuestApproved"), object: nil)
        }
        .onChange(of: afterparty.guestRequests.count) {
            print("🔵 GUEST BUTTON: Guest requests changed - refreshing data")
            refreshAfterpartyData()
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
        
        // Get the latest party data from the observed manager
        let latestParty = afterpartyManager.nearbyAfterparties.first { $0.id == afterparty.id } ?? afterparty
        let buttonState = determineGuestButtonState(userId: currentUserId, party: latestParty)
        
        print("🔵 GUEST BUTTON: Rendering with state: \(buttonState)")
        
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
    
    private func determineGuestButtonState(userId: String, party: Afterparty) -> GuestButtonState {
        print("🔍 FIXED BUTTON: Determining button state for user \(userId)")
        print("🔍 FIXED BUTTON: Party ID: \(party.id)")
        
        // CRITICAL: Always get the freshest data from the manager
        let freshParty = afterpartyManager.nearbyAfterparties.first { $0.id == party.id } ?? party
        
        print("🔍 FIXED BUTTON: Original party activeUsers: \(party.activeUsers)")
        print("🔍 FIXED BUTTON: Fresh party activeUsers: \(freshParty.activeUsers)")
        print("🔍 FIXED BUTTON: Original guestRequests count: \(party.guestRequests.count)")
        print("🔍 FIXED BUTTON: Fresh guestRequests count: \(freshParty.guestRequests.count)")
        
        // PRIORITY CHECK: If user is in activeUsers in either version, they're going
        if freshParty.activeUsers.contains(userId) || party.activeUsers.contains(userId) {
            print("🔍 FIXED BUTTON: User found in activeUsers - state: going")
            return .going
        }
        
        // Debug guest requests in detail from fresh data
        if !freshParty.guestRequests.isEmpty {
            print("🔍 FIXED BUTTON: Fresh guest requests details:")
            for request in freshParty.guestRequests {
                print("  - User \(request.userId): approval=\(request.approvalStatus), payment=\(request.paymentStatus)")
            }
        }
        
        // Check if party is sold out
        if freshParty.activeUsers.count >= freshParty.maxGuestCount {
            print("🔍 FIXED BUTTON: Party is sold out - state: soldOut")
            return .soldOut
        }
        
        // Check guest requests using fresh data
        if let request = freshParty.guestRequests.first(where: { $0.userId == userId }) {
            print("🔍 FIXED BUTTON: Found request - approval: \(request.approvalStatus), payment: \(request.paymentStatus)")
            
            switch request.approvalStatus {
            case .pending:
                print("🔍 FIXED BUTTON: Request pending - state: pending")
                return .pending
            case .approved:
                // Check payment status first
                if request.paymentStatus == .paid {
                    print("🔍 FIXED BUTTON: Approved and PAID - state: going (waiting for activeUsers update)")
                    return .going
                }
                // If they're in activeUsers, they're going (this should have been caught above)
                else if freshParty.activeUsers.contains(userId) || party.activeUsers.contains(userId) {
                    print("🔍 FIXED BUTTON: Approved and in activeUsers - state: going")
                    return .going
                } else {
                    print("🔍 FIXED BUTTON: Approved but not in activeUsers - state: approved (need to pay)")
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
        print("🚨 BUTTON CLICKED! Handling action for state: \(state)")
        print("🚨 BUTTON CLICKED! Current payment sheet state: \(showingPaymentSheet)")
        print("🚨 BUTTON CLICKED! User ID: \(userId)")
        
        switch state {
        case .requestToJoin:
            print("🚨 BUTTON CLICKED: Showing contact host sheet")
            showingContactHost = true
        case .approved:
            print("🚨 BUTTON CLICKED: APPROVED STATE - Opening payment sheet!")
            print("🚨 BUTTON CLICKED: Setting showingPaymentSheet to true")
            showingPaymentSheet = true
            print("🚨 BUTTON CLICKED: showingPaymentSheet is now: \(showingPaymentSheet)")
        case .going:
            print("🚨 BUTTON CLICKED: User already going - no action needed")
        default:
            print("🚨 BUTTON CLICKED: No action for state: \(state)")
        }
    }
    
    // MARK: - Data Refresh
    
    private func refreshAfterpartyData() {
        print("🔄 FIXED BUTTON: Refreshing afterparty data")
        Task {
            do {
                let updatedParty = try await afterpartyManager.getAfterpartyById(afterparty.id)
                print("🔄 FIXED BUTTON: Data refreshed successfully")
                print("🔄 FIXED BUTTON: Updated guest requests: \(updatedParty.guestRequests.count)")
                print("🔄 FIXED BUTTON: Updated activeUsers: \(updatedParty.activeUsers)")
                
                // Check specific user status
                let currentUserId = authViewModel.currentUser?.uid ?? ""
                let userInActiveUsers = updatedParty.activeUsers.contains(currentUserId)
                print("🔄 FIXED BUTTON: Current user \(currentUserId) in activeUsers: \(userInActiveUsers)")
                
                if let userRequest = updatedParty.guestRequests.first(where: { $0.userId == currentUserId }) {
                    print("🔄 FIXED BUTTON: Current user request - approval: \(userRequest.approvalStatus), payment: \(userRequest.paymentStatus)")
                }
                
                // Force a view update by updating the afterpartyManager
                await MainActor.run {
                    // Update the nearby afterparties array
                    if let index = afterpartyManager.nearbyAfterparties.firstIndex(where: { $0.id == afterparty.id }) {
                        let oldParty = afterpartyManager.nearbyAfterparties[index]
                        afterpartyManager.nearbyAfterparties[index] = updatedParty
                        print("🔄 FIXED BUTTON: Updated party in nearbyAfterparties array")
                        print("🔄 FIXED BUTTON: Old activeUsers: \(oldParty.activeUsers)")
                        print("🔄 FIXED BUTTON: New activeUsers: \(updatedParty.activeUsers)")
                        
                        // Force UI refresh by triggering objectWillChange
                        afterpartyManager.objectWillChange.send()
                    }
                }
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