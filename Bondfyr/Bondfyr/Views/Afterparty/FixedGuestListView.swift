import SwiftUI
import CoreLocation

struct FixedGuestListView: View {
    let partyId: String
    let originalParty: Afterparty
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @StateObject private var fixedNotificationManager = FixedNotificationManager.shared
    
    // WORKING STATE MANAGEMENT - NO BROKEN BINDINGS
    @State private var currentParty: Afterparty?
    @State private var pendingRequests: [GuestRequest] = []
    @State private var approvedGuests: [GuestRequest] = []
    @State private var refreshing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                // Pending Approval Section
                if !pendingRequests.isEmpty {
                    Section(header: 
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                            Text("PENDING APPROVAL (\(pendingRequests.count))")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    ) {
                        ForEach(pendingRequests) { request in
                            FixedPendingGuestRow(
                                request: request,
                                partyId: partyId,
                                onApprove: { approveRequest(request) },
                                onDeny: { denyRequest(request) }
                            )
                        }
                    }
                } else {
                    Section("Pending Requests") {
                        Text("No pending requests")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                    }
                }
                
                // Approved Guests Section
                if !approvedGuests.isEmpty {
                    Section(header:
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("APPROVED - CAN ATTEND (\(approvedGuests.count))")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    ) {
                        ForEach(approvedGuests) { request in
                            FixedApprovedGuestRow(
                                request: request,
                                onVerifyPayment: request.paymentStatus == .proofSubmitted ? { verifyPaymentProof(request) } : nil,
                                onRejectPayment: request.paymentStatus == .proofSubmitted ? { rejectPaymentProof(request) } : nil
                            )
                        }
                    }
                }
                
                // Summary Section
                Section("📊 SUMMARY") {
                    HStack {
                        Text("Total Requests")
                        Spacer()
                        Text("\(pendingRequests.count + approvedGuests.count)")
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Pending")
                        Spacer()
                        Text("\(pendingRequests.count)")
                            .foregroundColor(.orange)
                    }
                    
                    HStack {
                        Text("Approved")
                        Spacer()
                        Text("\(approvedGuests.count)")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("Party Capacity")
                        Spacer()
                        Text("\(currentParty?.activeUsers.count ?? 0)/\(currentParty?.maxGuestCount ?? 0)")
                            .foregroundColor(.purple)
                    }
                }
            }
            .navigationTitle("Guest Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await refreshData()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(refreshing)
                }
            }
            .refreshable {
                await refreshData()
            }
        }
        .onAppear {
            print("🔍 GUEST LIST: View appeared - refreshing data")
            Task {
                await refreshData()
            }
            
            // Listen for payment completion notifications to refresh guest status
            NotificationCenter.default.addObserver(
                forName: Notification.Name("PaymentCompleted"),
                object: nil,
                queue: .main
            ) { notification in
                print("🔔 GUEST LIST: Received payment completion notification - refreshing")
                // Check if this notification is for our party
                let notificationPartyId = notification.object as? String ?? notification.userInfo?["partyId"] as? String
                if let partyId = notificationPartyId, partyId == originalParty.id {
                    print("🔔 GUEST LIST: Notification is for our party - refreshing data")
                    Task {
                        await refreshData()
                    }
                } else {
                    print("🔔 GUEST LIST: Notification is for different party or no party ID - refreshing anyway")
                    Task {
                        await refreshData()
                    }
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: Notification.Name("PaymentCompleted"), object: nil)
        }
        .alert("Action Result", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Data Loading
    private func loadInitialData() async {
        print("🔄 FIXED LIST: Loading initial data for party \(partyId)")
        await refreshData()
    }
    
    @MainActor
    private func refreshData() async {
        print("🔄 FIXED LIST: Refreshing data...")
        refreshing = true
        defer { refreshing = false }
        
        do {
            // Get fresh party data from Firebase
            let freshParty = try await afterpartyManager.getAfterpartyById(partyId)
            
            currentParty = freshParty
            
            // Enhanced Debug Logging
            print("🔍 GUEST LIST DEBUG: Party ID: \(partyId)")
            print("🔍 GUEST LIST DEBUG: Total guest requests: \(freshParty.guestRequests.count)")
            print("🔍 GUEST LIST DEBUG: All guest requests:")
            for (i, request) in freshParty.guestRequests.enumerated() {
                print("   [\(i)] \(request.userHandle) - Status: \(request.approvalStatus) - Payment: \(request.paymentStatus)")
            }
            
            // Update request lists
            pendingRequests = freshParty.guestRequests.filter { $0.approvalStatus == .pending }
            approvedGuests = freshParty.guestRequests.filter { $0.approvalStatus == .approved }
            
            print("🔄 FIXED LIST: Data refreshed - Pending: \(pendingRequests.count), Approved: \(approvedGuests.count)")
            print("🔄 FIXED LIST: Active users: \(freshParty.activeUsers.count)")
            print("🔄 FIXED LIST: ActiveUsers list: \(freshParty.activeUsers)")
            
            if pendingRequests.isEmpty && approvedGuests.isEmpty {
                print("⚠️ GUEST LIST WARNING: No guest requests found! This could mean:")
                print("   1. No one has requested to join this party yet")
                print("   2. The party data structure might be incorrect")
                print("   3. Database sync issue")
            }
            
            // Debug payment status for all guest requests
            for (index, request) in freshParty.guestRequests.enumerated() {
                print("🔄 FIXED LIST: Request \(index): \(request.userHandle) - Approval: \(request.approvalStatus), Payment: \(request.paymentStatus)")
                if request.paymentStatus == .paid {
                    print("✅ FIXED LIST: \(request.userHandle) has PAID status!")
                }
                if request.paymentStatus == .proofSubmitted {
                    print("🟡 FIXED LIST: \(request.userHandle) has PROOF SUBMITTED! ProofURL: \(request.paymentProofImageURL ?? "nil")")
                    print("🟡 FIXED LIST: \(request.userHandle) proofSubmittedAt: \(request.proofSubmittedAt?.description ?? "nil")")
                }
            }
            
        } catch {
            print("🔴 FIXED LIST: Error refreshing data: \(error)")
            alertMessage = "Failed to refresh data: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    // MARK: - Actions
    private func approveRequest(_ request: GuestRequest) {
        print("✅ FIXED LIST: Approving request for \(request.userHandle)")
        
        Task {
            do {
                // Approve the request
                try await afterpartyManager.approveGuestRequest(
                    afterpartyId: partyId,
                    guestRequestId: request.id
                )
                
                // FIXED: Use new notification system
                // COMMENTED OUT: Local notifications show on the wrong device
                /*
                await fixedNotificationManager.notifyGuestOfApproval(
                    partyId: partyId,
                    partyTitle: currentParty?.title ?? "Party",
                    hostName: currentParty?.hostHandle ?? "Host",
                    guestUserId: request.userId,
                    amount: currentParty?.ticketPrice ?? 10
                )
                */
                
                await MainActor.run {
                    alertMessage = "✅ @\(request.userHandle) approved! They'll receive payment instructions."
                    showingAlert = true
                }
                
                // Refresh to show updated state
                await refreshData()
                
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to approve: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func denyRequest(_ request: GuestRequest) {
        print("❌ FIXED LIST: Denying request for \(request.userHandle)")
        
        Task {
            do {
                try await afterpartyManager.denyGuestRequest(
                    afterpartyId: partyId,
                    guestRequestId: request.id
                )
                
                await MainActor.run {
                    alertMessage = "❌ @\(request.userHandle) denied."
                    showingAlert = true
                }
                
                // Refresh to show updated state
                await refreshData()
                
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to deny: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    // MARK: - Payment Verification Actions
    private func verifyPaymentProof(_ request: GuestRequest) {
        print("✅ VERIFY: Verifying payment proof for \(request.userHandle)")
        
        Task {
            do {
                try await afterpartyManager.verifyPaymentProof(
                    afterpartyId: partyId,
                    guestRequestId: request.id,
                    approved: true
                )
                
                await MainActor.run {
                    alertMessage = "✅ Payment verified for @\(request.userHandle)"
                    showingAlert = true
                }
                
                // Refresh to show updated state
                await refreshData()
                
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to verify payment: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func rejectPaymentProof(_ request: GuestRequest) {
        print("❌ REJECT: Rejecting payment proof for \(request.userHandle)")
        
        Task {
            do {
                try await afterpartyManager.verifyPaymentProof(
                    afterpartyId: partyId,
                    guestRequestId: request.id,
                    approved: false
                )
                
                await MainActor.run {
                    alertMessage = "❌ Payment proof rejected for @\(request.userHandle)"
                    showingAlert = true
                }
                
                // Refresh to show updated state
                await refreshData()
                
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to reject payment proof: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - Preview
struct FixedGuestListView_Previews: PreviewProvider {
    static var previews: some View {
        FixedGuestListView(partyId: "test123", originalParty: Afterparty.preview)
    }
} 