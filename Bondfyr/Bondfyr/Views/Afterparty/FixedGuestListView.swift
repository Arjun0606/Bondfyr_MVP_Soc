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
                            FixedApprovedGuestRow(request: request)
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
            Task {
                await loadInitialData()
            }
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
            
            // Update request lists
            pendingRequests = freshParty.guestRequests.filter { $0.approvalStatus == .pending }
            approvedGuests = freshParty.guestRequests.filter { $0.approvalStatus == .approved }
            
            print("🔄 FIXED LIST: Data refreshed - Pending: \(pendingRequests.count), Approved: \(approvedGuests.count)")
            
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
                await fixedNotificationManager.notifyGuestOfApproval(
                    partyId: partyId,
                    partyTitle: currentParty?.title ?? "Party",
                    hostName: currentParty?.hostHandle ?? "Host",
                    guestUserId: request.userId,
                    amount: currentParty?.ticketPrice ?? 10
                )
                
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
}

// MARK: - Preview
struct FixedGuestListView_Previews: PreviewProvider {
    static var previews: some View {
        FixedGuestListView(partyId: "test123", originalParty: Afterparty.preview)
    }
} 