import SwiftUI
import FirebaseAuth

/// FIXED ACTION BUTTONS - Properly handles payment flow and button states
struct FixedActionButtonsView: View {
    let afterparty: Afterparty
    let isHost: Bool
    @Binding var showingGuestList: Bool
    @Binding var showingEditSheet: Bool
    @Binding var showingDeleteConfirmation: Bool
    @Binding var showingShareSheet: Bool
    @Binding var showingContactHost: Bool
    @Binding var showingPaymentSheet: Bool
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    @ObservedObject private var afterpartyManager = AfterpartyManager.shared
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        HStack(spacing: 12) {
            if isHost {
                hostControlsMenu
            } else {
                guestActionButton
            }
            
            shareButton
        }
    }
    
    // MARK: - Host Controls
    
    private var hostControlsMenu: some View {
        Menu {
            Button(action: { showingGuestList = true }) {
                Label("Manage Guests (\(guestRequestCount))", systemImage: "person.2.fill")
            }
            
            Button(action: { showingEditSheet = true }) {
                Label("Edit Party", systemImage: "pencil")
            }
            
            Button(action: { showingDeleteConfirmation = true }) {
                Label("Cancel Party", systemImage: "xmark.circle")
            }
        } label: {
            HStack {
                Image(systemName: "gear")
                Text("Manage")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(20)
        }
    }
    
    private var guestRequestCount: Int {
        afterparty.guestRequests.filter { $0.approvalStatus == .pending }.count
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
            .cornerRadius(20)
        }
        .disabled(isLoading || !buttonState.isEnabled)
        .alert("Notice", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Button State Logic (FIXED)
    
    private enum GuestButtonState {
        case requestToJoin
        case pending
        case approved // NEW: Approved but payment pending
        case proofSubmitted // NEW: Payment proof submitted, awaiting verification
        case going
        case denied
        case soldOut
        
        var isEnabled: Bool {
            switch self {
            case .requestToJoin, .approved: return true
            case .pending, .proofSubmitted, .going, .denied, .soldOut: return false
            }
        }
    }
    
    private func determineGuestButtonState(userId: String) -> GuestButtonState {
        print("🔍 FIXED: Determining button state for user \(userId)")
        print("🔍 FIXED: activeUsers: \(afterparty.activeUsers)")
        print("🔍 FIXED: guestRequests count: \(afterparty.guestRequests.count)")
        
        // BULLETPROOF CHECK: User must be BOTH in activeUsers AND have paid status
        let inActiveUsers = afterparty.activeUsers.contains(userId)
        let userRequest = afterparty.guestRequests.first(where: { $0.userId == userId })
        let hasPaidStatus = userRequest?.paymentStatus == .paid
        
        if inActiveUsers && hasPaidStatus {
            print("🔍 FIXED: ✅ User in activeUsers with PAID status - state: going")
            return .going
        } else if inActiveUsers && !hasPaidStatus {
            print("🚨 FIXED: ⚠️ DATA INCONSISTENCY! User in activeUsers but payment status: \(userRequest?.paymentStatus.rawValue ?? "unknown")")
            print("🚨 FIXED: ⚠️ FORCING correct state based on payment status.")
            
            // FORCE the correct state based on payment status, ignoring activeUsers
            if let request = userRequest {
                if request.paymentStatus == .proofSubmitted {
                    print("🚨 FIXED: ✅ FORCING proofSubmitted state (ignoring activeUsers)")
                    return .proofSubmitted
                } else if request.approvalStatus == .approved {
                    print("🚨 FIXED: ✅ FORCING approved state (ignoring activeUsers)")
                    return .approved
                }
            }
            // If no request found, continue with normal logic
        }
        
        // Check if party is sold out
        if afterparty.activeUsers.count >= afterparty.maxGuestCount {
            print("🔍 FIXED: Party is sold out - state: soldOut")
            return .soldOut
        }
        
        // Check guest requests
        if let request = afterparty.guestRequests.first(where: { $0.userId == userId }) {
            print("🔍 FIXED: Found request - approval: \(request.approvalStatus), payment: \(request.paymentStatus)")
            
            switch request.approvalStatus {
            case .pending:
                print("🔍 FIXED: Request pending - state: pending")
                return .pending
            case .approved:
                // Check payment status to determine exact state
                if request.paymentStatus == .paid {
                    print("🔍 FIXED: Approved and PAID - state: going (waiting for activeUsers update)")
                    return .going
                } else if request.paymentStatus == .proofSubmitted {
                    print("🔍 FIXED: Approved with proof submitted - state: proofSubmitted")
                    return .proofSubmitted
                } else {
                    print("🔍 FIXED: Approved but needs to pay - state: approved")
                    return .approved // Need to pay!
                }
            case .denied:
                print("🔍 FIXED: Request denied - state: denied")
                return .denied
            }
        }
        
        print("🔍 FIXED: No request found - state: requestToJoin")
        return .requestToJoin
    }
    
    @ViewBuilder
    private func buttonContent(for state: GuestButtonState) -> some View {
        switch state {
        case .requestToJoin:
            Image(systemName: "person.badge.plus")
            Text("Request to Join")
        case .pending:
            Image(systemName: "clock.fill")
            Text("Pending")
        case .approved:
            Image(systemName: "creditcard.fill")
            Text("Complete Payment ($\(Int(afterparty.ticketPrice)))")
        case .proofSubmitted:
            Image(systemName: "hourglass")
            Text("Payment Pending Verification...")
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
        case .proofSubmitted:
            return AnyView(Color.yellow) // Yellow for awaiting verification
        case .going:
            return AnyView(Color.green)
        case .denied, .soldOut:
            return AnyView(Color.gray)
        }
    }
    
    // MARK: - Action Handling (FIXED)
    
    private func handleGuestAction(state: GuestButtonState, userId: String) {
        print("🔍 FIXED: Handling guest action for state: \(state)")
        
        switch state {
        case .requestToJoin:
            print("🔍 FIXED: Opening request sheet")
            showingContactHost = true
            
        case .approved:
            print("🔍 FIXED: Opening payment sheet - user is approved!")
            showingPaymentSheet = true
            
        default:
            print("🔍 FIXED: No action for state: \(state)")
            break
        }
    }
    
    // MARK: - Share Button
    
    private var shareButton: some View {
        Button(action: { showingShareSheet = true }) {
            Image(systemName: "square.and.arrow.up")
                .padding(8)
                .background(Color(.systemGray6))
                .foregroundColor(.white)
                .cornerRadius(20)
        }
    }
} 