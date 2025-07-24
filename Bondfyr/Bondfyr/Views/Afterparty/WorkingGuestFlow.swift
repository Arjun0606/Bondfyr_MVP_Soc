import SwiftUI
import UserNotifications
import FirebaseAuth

/// WORKING GUEST FLOW - Handles notifications and payments correctly!
struct WorkingGuestFlow: View {
    let afterparty: Afterparty
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    
    @State private var guestStatus: GuestFlowStatus = .notRequested
    @State private var showingRequestSheet = false
    @State private var showingPaymentSheet = false
    @State private var isLoading = false
    
    enum GuestFlowStatus {
        case notRequested
        case pending
        case approved
        case proofSubmitted // NEW: Payment proof uploaded, awaiting host verification
        case paid
        case denied
    }
    
    var body: some View {
        Button(action: handleAction) {
            HStack {
                Image(systemName: buttonIcon)
                Text(buttonText)
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(buttonColor)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isLoading)
        .onAppear {
            checkGuestStatus()
        }
        .onChange(of: afterparty.guestRequests) {
            checkGuestStatus()
        }
        .sheet(isPresented: $showingRequestSheet) {
            RequestToJoinSheet(afterparty: afterparty) {
                checkGuestStatus()
                sendHostNotification()
            }
        }
        .sheet(isPresented: $showingPaymentSheet) {
            P2PPaymentSheet(afterparty: afterparty) {
                checkGuestStatus()
                sendHostPaymentNotification()
            }
        }
    }
    
    // MARK: - Guest Status Logic
    private func checkGuestStatus() {
        guard let currentUserId = authViewModel.currentUser?.uid else {
            guestStatus = .notRequested
            return
        }
        
        if let request = afterparty.guestRequests.first(where: { $0.userId == currentUserId }) {
            switch (request.approvalStatus, request.paymentStatus) {
            case (.pending, _):
                guestStatus = .pending
            case (.approved, .pending):
                guestStatus = .approved
                // Guest can choose when to pay - no auto-trigger
            case (.approved, .proofSubmitted):
                guestStatus = .proofSubmitted
                // Payment proof submitted, waiting for host verification
            case (.approved, .paid):
                guestStatus = .paid
            case (.denied, _):
                guestStatus = .denied
            default:
                guestStatus = .notRequested
            }
        } else {
            guestStatus = .notRequested
        }
    }
    
    // MARK: - Actions
    private func handleAction() {
        switch guestStatus {
        case .notRequested:
            showingRequestSheet = true
        case .approved:
            showingPaymentSheet = true
        default:
            break
        }
    }
    
    // MARK: - Button Properties
    private var buttonText: String {
        switch guestStatus {
        case .notRequested:
            return "Send Request"
        case .pending:
            return "Request Pending..."
        case .approved:
            return "Complete Payment ($\(Int(afterparty.ticketPrice)))"
        case .proofSubmitted:
            return "Payment Pending Verification..."
        case .paid:
            return "You're Going! 🎉"
        case .denied:
            return "Request Denied"
        }
    }
    
    private var buttonIcon: String {
        switch guestStatus {
        case .notRequested:
            return "plus.circle"
        case .pending:
            return "clock"
        case .approved:
            return "creditcard"
        case .proofSubmitted:
            return "hourglass"
        case .paid:
            return "checkmark.circle"
        case .denied:
            return "xmark.circle"
        }
    }
    
    private var buttonColor: Color {
        switch guestStatus {
        case .notRequested:
            return .blue
        case .pending:
            return .orange
        case .approved:
            return .green
        case .proofSubmitted:
            return .yellow
        case .paid:
            return .purple
        case .denied:
            return .red
        }
    }
    
    // MARK: - Notifications (DISABLED - Using FCM instead)
    
    /// When guest sends request → notify HOST
    private func sendHostNotification() {
        // DISABLED: Local notifications show on wrong device
        // This is now handled by Firebase Cloud Functions
        /*
        Task {
            let content = UNMutableNotificationContent()
            content.title = "🔔 New Guest Request"
            content.body = "\(authViewModel.currentUser?.name ?? "Someone") wants to join \(afterparty.title). Tap to review!"
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "host_new_guest_\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            
            try? await UNUserNotificationCenter.current().add(request)
            print("✅ WORKING: Sent HOST notification about new guest request")
        }
        */
    }
    
    /// When host approves guest → notify GUEST
    private func sendGuestApprovalNotification() {
        // DISABLED: Local notifications show on wrong device
        // This is now handled by Firebase Cloud Functions
        /*
        Task {
            let content = UNMutableNotificationContent()
            content.title = "🎉 Request Approved!"
            content.body = "You're approved for \(afterparty.title)! Complete payment ($\(Int(afterparty.ticketPrice))) to secure your spot."
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "guest_approved_\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            
            try? await UNUserNotificationCenter.current().add(request)
            print("✅ WORKING: Sent GUEST notification about approval")
        }
        */
    }
    
    /// When guest pays → notify HOST
    private func sendHostPaymentNotification() {
        // DISABLED: Local notifications show on wrong device
        // This is now handled by Firebase Cloud Functions
        /*
        guard let currentUser = authViewModel.currentUser else { return }
        
        Task {
            let content = UNMutableNotificationContent()
            content.title = "💰 Payment Received!"
            content.body = "\(currentUser.name) paid $\(Int(afterparty.ticketPrice)) for \(afterparty.title)."
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "host_payment_received_\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            
            try? await UNUserNotificationCenter.current().add(request)
            print("✅ WORKING: Sent HOST notification about payment received")
        }
        */
    }
} 