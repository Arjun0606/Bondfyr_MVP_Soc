import SwiftUI
import CoreLocation

// MARK: - Guest Dashboard (World-Class)
struct GuestDashboard: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var realTimeManager = RealTimePartyManager.shared
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    
    @State private var selectedTab: DashboardTab = .active
    @State private var showingPartyBrowser = false
    @State private var searchText = ""
    @Namespace private var tabAnimation
    
    private var currentUserId: String {
        authViewModel.currentUser?.uid ?? ""
    }
    
    enum DashboardTab: String, CaseIterable {
        case active = "Active"
        case pending = "Pending"
        case history = "History"
        
        var icon: String {
            switch self {
            case .active: return "party.popper.fill"
            case .pending: return "clock.arrow.circlepath"
            case .history: return "clock.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .active: return .green
            case .pending: return .orange
            case .history: return .blue
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Header with User Stats
                GuestHeaderCard(
                    activeParties: activeParties.count,
                    pendingRequests: pendingRequests.count,
                    onProfileTap: { }
                )
                .padding(.horizontal)
                .padding(.top)
                
                // MARK: - Tab Selector
                TabSelector(selectedTab: $selectedTab, namespace: tabAnimation)
                    .padding(.horizontal)
                
                // MARK: - Content
                TabView(selection: $selectedTab) {
                    // Active Parties
                    ActivePartiesView(parties: activeParties)
                        .tag(DashboardTab.active)
                    
                    // Pending Requests
                    PendingRequestsView(
                        requests: pendingRequests,
                        onCancelRequest: cancelRequest
                    )
                    .tag(DashboardTab.pending)
                    
                    // History
                    PartyHistoryView(parties: historyParties)
                        .tag(DashboardTab.history)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // MARK: - Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showingPartyBrowser = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text("Find Parties")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.purple, .pink]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Text("Your Parties")
                    .font(.title2)
                    .fontWeight(.bold),
                trailing: Button(action: { showingPartyBrowser = true }) {
                    Image(systemName: "magnifyingglass")
                }
            )
        }
        .onAppear {
            realTimeManager.startMonitoringUserParties()
            realTimeManager.enableSmartNotifications()
        }
        .sheet(isPresented: $showingPartyBrowser) {
            PartyBrowserPlaceholderView()
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Computed Properties
    private var activeParties: [GuestPartyInfo] {
        realTimeManager.parties.values.compactMap { party in
            // Filter out ended parties
            guard party.endTime > Date() else { return nil }
            
            guard let status = realTimeManager.getUserStatus(for: party.id),
                  status == .going || status == .approved else { return nil }
            
            return GuestPartyInfo(party: party, status: status, lastUpdate: Date())
        }.sorted { $0.party.startTime < $1.party.startTime }
    }
    
    private var pendingRequests: [GuestPartyInfo] {
        realTimeManager.parties.values.compactMap { party in
            // Filter out ended parties
            guard party.endTime > Date() else { return nil }
            
            guard let status = realTimeManager.getUserStatus(for: party.id),
                  status == .requestSubmitted else { return nil }
            
            return GuestPartyInfo(party: party, status: status, lastUpdate: Date())
        }.sorted { $0.party.startTime < $1.party.startTime }
    }
    
    private var historyParties: [GuestPartyInfo] {
        realTimeManager.parties.values.compactMap { party in
            guard party.endTime < Date() else { return nil }
            
            let status = realTimeManager.getUserStatus(for: party.id) ?? .partyEnded
            return GuestPartyInfo(party: party, status: status, lastUpdate: party.endTime)
        }.sorted { $0.party.endTime > $1.party.endTime }
    }
    
    // MARK: - Actions
    private func cancelRequest(_ party: Afterparty) {
        // TODO: Implement request cancellation
        print("🔴 GUEST: Cancelling request for party \(party.id)")
    }
}

// MARK: - Guest Party Info
struct GuestPartyInfo {
    let party: Afterparty
    let status: PartyGuestStatus
    let lastUpdate: Date
}

// MARK: - Guest Header Card
struct GuestHeaderCard: View {
    let activeParties: Int
    let pendingRequests: Int
    let onProfileTap: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            // Profile section
            Button(action: onProfileTap) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.secondary)
                                .font(.title3)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Welcome back!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Party Time 🎉")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
            }
            
            Spacer()
            
            // Stats
            HStack(spacing: 16) {
                StatCard(
                    value: "\(activeParties)",
                    label: "Active",
                    color: .green,
                    icon: "party.popper.fill"
                )
                
                StatCard(
                    value: "\(pendingRequests)",
                    label: "Pending",
                    color: .orange,
                    icon: "clock.arrow.circlepath"
                )
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

struct StatCard: View {
    let value: String
    let label: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Tab Selector
struct TabSelector: View {
    @Binding var selectedTab: GuestDashboard.DashboardTab
    let namespace: Namespace.ID
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(GuestDashboard.DashboardTab.allCases, id: \.self) { tab in
                TabSelectorButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                    },
                    namespace: namespace
                )
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Active Parties View
struct ActivePartiesView: View {
    let parties: [GuestPartyInfo]
    
    var body: some View {
        ScrollView {
            if parties.isEmpty {
                EmptyActivePartiesView()
                    .frame(maxHeight: .infinity)
                    .padding(.top, 60)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(parties, id: \.party.id) { partyInfo in
                        ActivePartyCard(partyInfo: partyInfo)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
        }
    }
}

struct ActivePartyCard: View {
    let partyInfo: GuestPartyInfo
    @State private var showingChat = false
    @State private var showingDetails = false
    
    private var timeStatus: String {
        let now = Date()
        if partyInfo.party.startTime > now {
            let timeInterval = partyInfo.party.startTime.timeIntervalSince(now)
            if timeInterval < 3600 {
                return "Starting in \(Int(timeInterval/60))m"
            } else {
                return "Starts at \(partyInfo.party.startTime.formatted(.dateTime.hour().minute()))"
            }
        } else if partyInfo.party.endTime > now {
            return "Live Now! 🔥"
        } else {
            return "Ended"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(partyInfo.party.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    Text("@\(partyInfo.party.hostHandle)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusIndicator(status: partyInfo.status)
            }
            
            // Party info
            HStack {
                InfoItem(icon: "clock.fill", text: timeStatus, color: .orange)
                Spacer()
                InfoItem(icon: "location.fill", text: partyInfo.party.locationName, color: .blue)
                Spacer()
                InfoItem(icon: "person.3.fill", text: "\(partyInfo.party.activeUsers.count)/\(partyInfo.party.maxGuestCount)", color: .green)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                if partyInfo.status == .going {
                    // Join Chat button (primary)
                    Button(action: { showingChat = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                            Text("Join Chat")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .cyan]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                } else if partyInfo.status == .approved {
                    // Activate button
                    Button(action: { /* Activate party access */ }) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Activate Access")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.green)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                
                // Details button (secondary)
                Button(action: { showingDetails = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                        Text("Details")
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
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
        .sheet(isPresented: $showingChat) {
            PartyChatView(afterparty: partyInfo.party)
        }
        .sheet(isPresented: $showingDetails) {
            PartyDetailsPlaceholderView(party: partyInfo.party)
        }
    }
}

struct InfoItem: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct StatusIndicator: View {
    let status: PartyGuestStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            Text(status.displayText)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(status.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Pending Requests View
struct PendingRequestsView: View {
    let requests: [GuestPartyInfo]
    let onCancelRequest: (Afterparty) -> Void
    
    var body: some View {
        ScrollView {
            if requests.isEmpty {
                EmptyPendingRequestsView()
                    .frame(maxHeight: .infinity)
                    .padding(.top, 60)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(requests, id: \.party.id) { requestInfo in
                        PendingRequestCard(
                            partyInfo: requestInfo,
                            onCancel: { onCancelRequest(requestInfo.party) }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
        }
    }
}

struct PendingRequestCard: View {
    let partyInfo: GuestPartyInfo
    let onCancel: () -> Void
    
    private var requestTimeAgo: String {
        let interval = Date().timeIntervalSince(partyInfo.lastUpdate)
        if interval < 3600 {
            return "\(Int(interval/60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval/3600))h ago"
        } else {
            return "\(Int(interval/86400))d ago"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(partyInfo.party.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Requested \(requestTimeAgo)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.orange)
                        .font(.title3)
                    Text("Pending")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)
                }
            }
            
            // Progress indicator
            VStack(spacing: 8) {
                HStack {
                    Text("Waiting for host approval...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                    .scaleEffect(y: 0.5)
            }
            
            // Actions
            HStack {
                Button(action: onCancel) {
                    Text("Cancel Request")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Spacer()
                
                Text("Expected response: 1-2 hours")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Party History View
struct PartyHistoryView: View {
    let parties: [GuestPartyInfo]
    
    var body: some View {
        ScrollView {
            if parties.isEmpty {
                EmptyHistoryView()
                    .frame(maxHeight: .infinity)
                    .padding(.top, 60)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(parties, id: \.party.id) { partyInfo in
                        HistoryPartyCard(partyInfo: partyInfo)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
        }
    }
}

struct HistoryPartyCard: View {
    let partyInfo: GuestPartyInfo
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(partyInfo.party.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(partyInfo.party.endTime.formatted(.dateTime.month().day().hour().minute()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            StatusIndicator(status: partyInfo.status)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Empty State Views
struct EmptyActivePartiesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "party.popper")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Active Parties")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("When you're approved for parties, they'll appear here with chat access.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

struct EmptyPendingRequestsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Pending Requests")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Your party requests will appear here while waiting for host approval.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Party History")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Your past parties will appear here after they end.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Placeholder Views
struct PartyBrowserPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: 80))
                    .foregroundColor(.secondary)
                
                Text("Party Browser")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Coming soon! You'll be able to browse and discover parties in your area.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .navigationTitle("Browse Parties")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PartyDetailsPlaceholderView: View {
    let party: Afterparty
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Text(party.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Hosted by @\(party.hostHandle)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Basic Info
                    VStack(spacing: 16) {
                        PartyInfoRow(icon: "clock.fill", title: "Time", 
                               value: "\(party.startTime.formatted(.dateTime.weekday().month().day().hour().minute())) - \(party.endTime.formatted(.dateTime.hour().minute()))")
                        
                        PartyInfoRow(icon: "location.fill", title: "Location", value: party.locationName)
                        
                        PartyInfoRow(icon: "person.3.fill", title: "Capacity", 
                               value: "\(party.activeUsers.count)/\(party.maxGuestCount) guests")
                        
                        if !party.description.isEmpty {
                            PartyInfoRow(icon: "text.alignleft", title: "Description", value: party.description)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 100)
                    
                    Text("Full party details coming soon!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Party Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PartyInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct TabSelectorButton: View {
    let tab: GuestDashboard.DashboardTab
    let isSelected: Bool
    let action: () -> Void
    let namespace: Namespace.ID
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.caption)
                Text(tab.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(tab.color)
                            .matchedGeometryEffect(id: "tab", in: namespace)
                    }
                }
            )
        }
    }
} 