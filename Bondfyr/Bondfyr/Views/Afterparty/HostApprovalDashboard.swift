import SwiftUI
import FirebaseFirestore

// MARK: - Host Approval Dashboard (World-Class)
struct HostApprovalDashboard: View {
    let party: Afterparty
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var realTimeManager = RealTimePartyManager.shared
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    
    @State private var selectedRequests = Set<String>()
    @State private var showingBatchActions = false
    @State private var isProcessingBatch = false
    @State private var searchText = ""
    @State private var filterOption: FilterOption = .all
    @State private var showingPartyAnalytics = false
    @State private var refreshTrigger = 0 // Force view refresh when party updates
    
    // Real-time party data
    private var currentParty: Afterparty {
        print("🔍 HOST DASHBOARD: currentParty computed - ID: \(party.id)")
        let updatedParty = realTimeManager.getParty(party.id) ?? party
        print("🔍 HOST DASHBOARD: Found \(updatedParty.guestRequests.count) requests")
        print("🔍 HOST DASHBOARD: Original party had \(party.guestRequests.count) requests")
        print("🔍 HOST DASHBOARD: Real-time manager has party: \(realTimeManager.getParty(party.id) != nil)")
        return updatedParty
    }
    
    private var filteredRequests: [GuestRequest] {
        let requests = currentParty.guestRequests.filter { request in
            print("🔍 FILTER: Checking request from \(request.userHandle) with status \(request.approvalStatus), payment: \(request.paymentStatus)")
            switch filterOption {
            case .all:
                return true
            case .pending:
                return request.approvalStatus == .pending
            case .approved:
                return request.approvalStatus == .approved && request.paymentStatus == .pending
            case .paymentVerification:
                return request.approvalStatus == .approved && request.paymentStatus == .proofSubmitted
            case .paid:
                return request.paymentStatus == .paid
            }
        }
        
        print("🔍 FILTER: After filtering (\(filterOption.rawValue)): \(requests.count) requests")
        
        if searchText.isEmpty {
            return requests.sorted { $0.requestedAt > $1.requestedAt }
        } else {
            return requests.filter {
                $0.userHandle.localizedCaseInsensitiveContains(searchText) ||
                $0.userName.localizedCaseInsensitiveContains(searchText) ||
                $0.introMessage.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.requestedAt > $1.requestedAt }
        }
    }
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case approved = "Approved"
        case paymentVerification = "Payment Verification" // NEW: Payment proof verification
        case paid = "Paid"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .pending: return "clock.arrow.circlepath"
            case .approved: return "checkmark.circle"
            case .paymentVerification: return "hourglass"
            case .paid: return "creditcard.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Header with Analytics
                PartyHeaderCard(party: currentParty) {
                    showingPartyAnalytics = true
                }
                .padding(.horizontal)
                .padding(.top)
                
                // MARK: - Search & Filter Bar
                SearchAndFilterBar(
                    searchText: $searchText,
                    filterOption: $filterOption,
                    selectedCount: selectedRequests.count,
                    onBatchAction: { showingBatchActions = true }
                )
                .padding(.horizontal)
                
                // MARK: - Guest Requests List
                if filteredRequests.isEmpty {
                    EmptyStateView(filterOption: filterOption)
                        .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredRequests, id: \.id) { request in
                                GuestRequestCard(
                                    request: request,
                                    party: currentParty,
                                    isSelected: selectedRequests.contains(request.id),
                                    onSelectionToggle: { toggleSelection(request.id) },
                                    onApprove: { approveRequest(request) },
                                    onDeny: { denyRequest(request) },
                                    onVerifyPayment: request.paymentStatus == .proofSubmitted ? { verifyPaymentProof(request) } : nil,
                                    onRejectPayment: request.paymentStatus == .proofSubmitted ? { rejectPaymentProof(request) } : nil
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100) // Space for batch actions
                    }
                }
                
                Spacer()
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(action: { showingPartyAnalytics = true }) {
                    Image(systemName: "chart.bar.fill")
                }
            )
            .overlay(alignment: .bottom) {
                // Batch Actions Toolbar
                if !selectedRequests.isEmpty {
                    BatchActionsToolbar(
                        selectedCount: selectedRequests.count,
                        isProcessing: isProcessingBatch,
                        onApproveAll: approveSelectedRequests,
                        onDenyAll: denySelectedRequests,
                        onDeselectAll: deselectAll
                    )
                }
            }
        }
        .onAppear {
            print("🟢 HOST DASHBOARD: Starting to listen for party \(party.id)")
            print("🟢 HOST DASHBOARD: Current guest requests: \(party.guestRequests.count)")
            
            // CRITICAL FIX: Force immediate refresh from Firebase
            Task {
                do {
                    let freshParty = try await afterpartyManager.getAfterpartyById(party.id)
                    print("🔄 HOST DASHBOARD: Fresh party data - requests: \(freshParty.guestRequests.count)")
                } catch {
                    print("🔴 HOST DASHBOARD: Error fetching fresh party data: \(error)")
                }
            }
            
            realTimeManager.startListening(to: party.id)
        }
        .onDisappear {
            print("🔴 HOST DASHBOARD: Stopping listener for party \(party.id)")
            realTimeManager.stopListening(to: party.id)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PartyDataUpdated"))) { notification in
            print("🔄 HOST DASHBOARD: Received party data update notification")
            if let userInfo = notification.userInfo,
               let updatedPartyId = userInfo["partyId"] as? String,
               updatedPartyId == party.id,
               let updatedParty = userInfo["party"] as? Afterparty {
                print("🔄 HOST DASHBOARD: Party \(updatedPartyId) updated - guest requests: \(updatedParty.guestRequests.count)")
                
                // CRITICAL FIX: Force view refresh by updating a state variable
                DispatchQueue.main.async {
                    // Trigger view refresh
                    refreshTrigger += 1
                }
            }
        }
        .sheet(isPresented: $showingPartyAnalytics) {
            PartyAnalyticsSheet(party: currentParty)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Actions
    private func toggleSelection(_ requestId: String) {
        if selectedRequests.contains(requestId) {
            selectedRequests.remove(requestId)
        } else {
            selectedRequests.insert(requestId)
        }
    }
    
    private func approveRequest(_ request: GuestRequest) {
        Task {
            do {
                try await afterpartyManager.approveGuestRequest(
                    afterpartyId: currentParty.id,
                    guestRequestId: request.id
                )
                
                // Remove from selection if it was selected
                selectedRequests.remove(request.id)
                
                // Trigger success haptic
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                
            } catch {
                print("🔴 HOST: Error approving request: \(error)")
            }
        }
    }
    
    private func denyRequest(_ request: GuestRequest) {
        Task {
            do {
                try await afterpartyManager.denyGuestRequest(
                    afterpartyId: currentParty.id,
                    guestRequestId: request.id
                )
                
                // Remove from selection if it was selected
                selectedRequests.remove(request.id)
                
                // Trigger warning haptic
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                
            } catch {
                print("🔴 HOST: Error denying request: \(error)")
            }
        }
    }
    
    // MARK: - NEW: Payment Verification Actions
    
    private func verifyPaymentProof(_ request: GuestRequest) {
        Task {
            do {
                try await afterpartyManager.verifyPaymentProof(
                    afterpartyId: currentParty.id,
                    guestRequestId: request.id,
                    approved: true
                )
                
                // Remove from selection if it was selected
                selectedRequests.remove(request.id)
                
                // Trigger success haptic
                let impact = UIImpactFeedbackGenerator(style: .heavy)
                impact.impactOccurred()
                
                print("🟢 HOST: Payment verified for \(request.userHandle)")
                
            } catch {
                print("🔴 HOST: Error verifying payment: \(error)")
            }
        }
    }
    
    private func rejectPaymentProof(_ request: GuestRequest) {
        Task {
            do {
                try await afterpartyManager.verifyPaymentProof(
                    afterpartyId: currentParty.id,
                    guestRequestId: request.id,
                    approved: false
                )
                
                // Remove from selection if it was selected
                selectedRequests.remove(request.id)
                
                // Trigger warning haptic
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                
                print("🔴 HOST: Payment proof rejected for \(request.userHandle)")
                
            } catch {
                print("🔴 HOST: Error rejecting payment proof: \(error)")
            }
        }
    }
    
    private func approveSelectedRequests() {
        isProcessingBatch = true
        
        Task {
            for requestId in selectedRequests {
                if let request = currentParty.guestRequests.first(where: { $0.id == requestId }) {
                    try? await afterpartyManager.approveGuestRequest(
                        afterpartyId: currentParty.id,
                        guestRequestId: request.id
                    )
                }
            }
            
            await MainActor.run {
                selectedRequests.removeAll()
                isProcessingBatch = false
                
                // Success haptic
                let impact = UIImpactFeedbackGenerator(style: .heavy)
                impact.impactOccurred()
            }
        }
    }
    
    private func denySelectedRequests() {
        isProcessingBatch = true
        
        Task {
            for requestId in selectedRequests {
                if let request = currentParty.guestRequests.first(where: { $0.id == requestId }) {
                    try? await afterpartyManager.denyGuestRequest(
                        afterpartyId: currentParty.id,
                        guestRequestId: request.id
                    )
                }
            }
            
            await MainActor.run {
                selectedRequests.removeAll()
                isProcessingBatch = false
                
                // Warning haptic
                let impact = UIImpactFeedbackGenerator(style: .heavy)
                impact.impactOccurred()
            }
        }
    }
    
    private func deselectAll() {
        selectedRequests.removeAll()
    }
}

// MARK: - Party Header Card
struct PartyHeaderCard: View {
    let party: Afterparty
    let onAnalyticsTap: () -> Void
    
    private var capacityInfo: PartyCapacityInfo {
        PartyCapacityInfo(current: party.activeUsers.count, maximum: party.maxGuestCount)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Title and basic info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(party.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(party.locationName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onAnalyticsTap) {
                    VStack(spacing: 4) {
                        Text("\(party.activeUsers.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Going")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            
            // Stats row
            HStack(spacing: 20) {
                StatItem(
                    icon: "person.2.fill",
                    value: "\(party.guestRequests.filter { $0.approvalStatus == .pending }.count)",
                    label: "Pending",
                    color: .orange
                )
                
                StatItem(
                    icon: "checkmark.circle.fill",
                    value: "\(party.guestRequests.filter { $0.approvalStatus == .approved }.count)",
                    label: "Approved",
                    color: .green
                )
                
                StatItem(
                    icon: "gauge.medium",
                    value: "\(Int(capacityInfo.percentage * 100))%",
                    label: "Capacity",
                    color: capacityInfo.isNearCapacity ? .red : .blue
                )
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Search and Filter Bar
struct SearchAndFilterBar: View {
    @Binding var searchText: String
    @Binding var filterOption: HostApprovalDashboard.FilterOption
    let selectedCount: Int
    let onBatchAction: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search guests...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Filter options
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(HostApprovalDashboard.FilterOption.allCases, id: \.self) { option in
                        FilterChip(
                            option: option,
                            isSelected: filterOption == option,
                            onTap: { filterOption = option }
                        )
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }
}

struct FilterChip: View {
    let option: HostApprovalDashboard.FilterOption
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.caption)
                Text(option.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Guest Request Card
struct GuestRequestCard: View {
    let request: GuestRequest
    let party: Afterparty
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    let onApprove: () -> Void
    let onDeny: () -> Void
    let onVerifyPayment: (() -> Void)? // NEW: Verify payment proof
    let onRejectPayment: (() -> Void)? // NEW: Reject payment proof
    
    @State private var isExpanded = false
    @State private var showingProfile = false
    @State private var showingPaymentProof = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 16) {
                // Selection indicator
                Button(action: onSelectionToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .secondary)
                        .font(.title3)
                }
                
                // User info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(request.userHandle)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        ApprovalStatusBadge(status: request.approvalStatus)
                        
                        // Payment Status Indicators
                        if request.paymentStatus == .paid {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else if request.paymentStatus == .proofSubmitted {
                            Image(systemName: "hourglass")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }
                    
                    Text(request.userName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !request.introMessage.isEmpty {
                        Text(request.introMessage)
                            .font(.subheadline)
                            .lineLimit(isExpanded ? nil : 2)
                            .padding(.top, 4)
                    }
                    
                    // Timestamp
                    Text("Requested \(timeAgoString(from: request.requestedAt))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                    
                    // Payment Proof Section (NEW)
                    if request.paymentStatus == .proofSubmitted,
                       let proofURL = request.paymentProofImageURL {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Payment Proof Submitted")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .padding(.top, 8)
                            
                            Button(action: { showingPaymentProof = true }) {
                                HStack {
                                    Image(systemName: "photo")
                                    Text("View Payment Screenshot")
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            }
                            
                            if let submittedAt = request.proofSubmittedAt {
                                Text("Submitted \(timeAgoString(from: submittedAt))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Actions
                if request.approvalStatus == .pending {
                    VStack(spacing: 8) {
                        Button(action: onApprove) {
                            Image(systemName: "checkmark")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(.green)
                                .clipShape(Circle())
                        }
                        
                        Button(action: onDeny) {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(.red)
                                .clipShape(Circle())
                        }
                    }
                } else if request.paymentStatus == .proofSubmitted,
                          let verifyAction = onVerifyPayment,
                          let rejectAction = onRejectPayment {
                    // NEW: Payment Verification Actions
                    VStack(spacing: 8) {
                        Button(action: verifyAction) {
                            VStack(spacing: 2) {
                                Image(systemName: "checkmark.circle")
                                    .font(.title3)
                                Text("Verify")
                                    .font(.caption2)
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Button(action: rejectAction) {
                            VStack(spacing: 2) {
                                Image(systemName: "xmark.circle")
                                    .font(.title3)
                                Text("Reject")
                                    .font(.caption2)
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.black.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? .blue : .clear, lineWidth: 2)
                    )
            )
            .onTapGesture {
                if !request.introMessage.isEmpty {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPaymentProof) {
            if let proofURL = request.paymentProofImageURL {
                PaymentProofSheet(imageURL: proofURL, guestHandle: request.userHandle)
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }
}

struct ApprovalStatusBadge: View {
    let status: ApprovalStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
            Text(statusText)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2))
        .foregroundColor(statusColor)
        .clipShape(Capsule())
    }
    
    private var statusIcon: String {
        switch status {
        case .pending: return "clock.arrow.circlepath"
        case .approved: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        }
    }
    
    private var statusText: String {
        switch status {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .denied: return "Denied"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .approved: return .green
        case .denied: return .red
        }
    }
}

// MARK: - Batch Actions Toolbar
struct BatchActionsToolbar: View {
    let selectedCount: Int
    let isProcessing: Bool
    let onApproveAll: () -> Void
    let onDenyAll: () -> Void
    let onDeselectAll: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 16) {
                // Selected count
                VStack(spacing: 2) {
                    Text("\(selectedCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Selected")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Actions
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(action: onApproveAll) {
                        Label("Approve All", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.green)
                            .clipShape(Capsule())
                    }
                    
                    Button(action: onDenyAll) {
                        Label("Deny All", systemImage: "xmark.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.red)
                            .clipShape(Capsule())
                    }
                    
                    Button(action: onDeselectAll) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let filterOption: HostApprovalDashboard.FilterOption
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(emptyStateTitle)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var emptyStateIcon: String {
        switch filterOption {
        case .all: return "person.badge.plus"
        case .pending: return "clock.arrow.circlepath"
        case .approved: return "checkmark.circle"
        case .paid: return "creditcard"
        case .paymentVerification: return "magnifyingglass.circle"
        }
    }
    
    private var emptyStateTitle: String {
        switch filterOption {
        case .all: return "No Guest Requests"
        case .pending: return "No Pending Requests"
        case .approved: return "No Approved Guests"
        case .paid: return "No Paid Guests"
        case .paymentVerification: return "No Payment Proofs"
        }
    }
    
    private var emptyStateMessage: String {
        switch filterOption {
        case .all: return "Guest requests will appear here once people start requesting to join your party."
        case .pending: return "All caught up! No requests waiting for your approval."
        case .approved: return "No guests have been approved yet."
        case .paid: return "No guests have completed payment yet."
        case .paymentVerification: return "No payment proofs waiting for verification."
        }
    }
}

// MARK: - Party Analytics Sheet
struct PartyAnalyticsSheet: View {
    let party: Afterparty
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // TODO: Add detailed analytics
                    Text("Party Analytics")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Coming soon...")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

// MARK: - Payment Proof Sheet
struct PaymentProofSheet: View {
    let imageURL: String
    let guestHandle: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } placeholder: {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Loading payment proof...")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                }
            }
            .navigationTitle("\(guestHandle)'s Payment Proof")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .preferredColorScheme(.dark)
        }
    }
}