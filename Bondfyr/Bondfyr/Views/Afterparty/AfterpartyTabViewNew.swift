import SwiftUI
import CoreLocation

// MARK: - Enhanced Afterparty Tab View
struct EnhancedAfterpartyTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var realTimeManager = RealTimePartyManager.shared
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @StateObject private var locationManager = LocationManager()
    
    @State private var selectedTab: PartyTab = .nearby
    @State private var nearbyParties: [Afterparty] = []
    @State private var searchText = ""
    @State private var showingFilters = false
    @State private var isRefreshing = false
    
    enum PartyTab: String, CaseIterable {
        case nearby = "Nearby"
        case mine = "My Parties"
        case dashboard = "Dashboard"
        
        var icon: String {
            switch self {
            case .nearby: return "location.fill"
            case .mine: return "person.crop.circle.fill"
            case .dashboard: return "chart.bar.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Enhanced Tab Bar
                EnhancedTabBar(selectedTab: $selectedTab, searchText: $searchText)
                    .padding(.horizontal)
                
                // MARK: - Content
                TabView(selection: $selectedTab) {
                    // Nearby Parties
                    NearbyPartiesView(
                        parties: filteredNearbyParties,
                        isRefreshing: $isRefreshing,
                        onRefresh: refreshNearbyParties
                    )
                    .tag(PartyTab.nearby)
                    
                    // My Parties (Hosted)
                    HostedPartiesView()
                        .tag(PartyTab.mine)
                    
                    // Guest Dashboard
                    GuestDashboard()
                        .tag(PartyTab.dashboard)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
        .onAppear {
            setupRealTimeUpdates()
            refreshNearbyParties()
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Computed Properties
    private var filteredNearbyParties: [Afterparty] {
        if searchText.isEmpty {
            return nearbyParties
        } else {
            return nearbyParties.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.locationName.localizedCaseInsensitiveContains(searchText) ||
                $0.hostHandle.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Setup
    private func setupRealTimeUpdates() {
        realTimeManager.startMonitoringUserParties()
        realTimeManager.enableSmartNotifications()
        
        // Start listening to nearby parties
        realTimeManager.startListeningToMultipleParties(nearbyParties.map { $0.id })
    }
    
    private func refreshNearbyParties() {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        Task {
            do {
                // Get user's location
                if let coordinate = locationManager.location?.coordinate {
                    // Set the location for the manager and fetch nearby parties
                    await afterpartyManager.fetchNearbyAfterparties()
                    
                    await MainActor.run {
                        nearbyParties = afterpartyManager.nearbyAfterparties
                        setupRealTimeUpdates()
                    }
                }
            } catch {
                print("🔴 ENHANCED: Error refreshing parties: \(error)")
            }
            
            await MainActor.run {
                isRefreshing = false
            }
        }
    }
}

// MARK: - Enhanced Tab Bar
struct EnhancedTabBar: View {
    @Binding var selectedTab: EnhancedAfterpartyTabView.PartyTab
    @Binding var searchText: String
    @Namespace private var tabAnimation
    
    var body: some View {
        VStack(spacing: 16) {
            // Tab selector
            HStack(spacing: 0) {
                ForEach(EnhancedAfterpartyTabView.PartyTab.allCases, id: \.self) { tab in
                    TabBarButton(tab: tab, selectedTab: $selectedTab, animation: tabAnimation)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            
            // Search bar (only for nearby)
            if selectedTab == .nearby {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search parties...", text: $searchText)
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
            }
        }
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let tab: EnhancedAfterpartyTabView.PartyTab
    @Binding var selectedTab: EnhancedAfterpartyTabView.PartyTab
    let animation: Namespace.ID
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                selectedTab = tab
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.caption)
                Text(tab.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(selectedTab == tab ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(backgroundView)
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if selectedTab == tab {
            RoundedRectangle(cornerRadius: 12)
                .fill(.purple)
                .matchedGeometryEffect(id: "tab", in: animation)
        }
    }
}

// MARK: - Nearby Parties View
struct NearbyPartiesView: View {
    let parties: [Afterparty]
    @Binding var isRefreshing: Bool
    let onRefresh: () -> Void
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        ScrollView {
            if parties.isEmpty {
                EmptyNearbyPartiesView(isRefreshing: isRefreshing)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 60)
            } else {
                LazyVStack(spacing: 20) {
                    ForEach(parties, id: \.id) { party in
                        EnhancedPartyCard(
                            party: party,
                            userId: authViewModel.currentUser?.uid ?? ""
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
        }
        .refreshable {
            onRefresh()
        }
    }
}

struct EmptyNearbyPartiesView: View {
    let isRefreshing: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if isRefreshing {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Finding parties near you...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "location.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                Text("No Parties Nearby")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("There are no parties in your area right now. Check back later or create your own!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Hosted Parties View
struct HostedPartiesView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var realTimeManager = RealTimePartyManager.shared
    @State private var showingCreateParty = false
    
    private var hostedParties: [Afterparty] {
        realTimeManager.parties.values.filter { party in
            party.userId == authViewModel.currentUser?.uid && party.endTime > Date()
        }.sorted { $0.startTime < $1.startTime }
    }
    
    var body: some View {
        ScrollView {
            if hostedParties.isEmpty {
                EmptyHostedPartiesView {
                    showingCreateParty = true
                }
                .frame(maxHeight: .infinity)
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(hostedParties, id: \.id) { party in
                        HostedPartyCard(party: party)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: { showingCreateParty = true }) {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(.purple)
                    .clipShape(Circle())
                    .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showingCreateParty) {
            CreateAfterpartyDirectView()
        }
    }
}

struct EmptyHostedPartiesView: View {
    let onCreateParty: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Host Your First Party")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Create amazing experiences for your friends and community.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: onCreateParty) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Party")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.pink]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Hosted Party Card
struct HostedPartyCard: View {
    let party: Afterparty
    @State private var showingDashboard = false
    @State private var showingAnalytics = false
    
    private var timeStatus: String {
        let now = Date()
        if party.startTime > now {
            let timeInterval = party.startTime.timeIntervalSince(now)
            if timeInterval < 3600 {
                return "Starting in \(Int(timeInterval/60))m"
            } else {
                return "Starts at \(party.startTime.formatted(.dateTime.hour().minute()))"
            }
        } else if party.endTime > now {
            return "Live Now! 🔥"
        } else {
            return "Ended"
        }
    }
    
    private var guestStats: (pending: Int, approved: Int, active: Int) {
        let pending = party.guestRequests.filter { $0.approvalStatus == .pending }.count
        let approved = party.guestRequests.filter { $0.approvalStatus == .approved }.count
        let active = party.activeUsers.count
        
        return (pending, approved, active)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(party.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    Text(timeStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("$\(Int(party.ticketPrice))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("per guest")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Stats row - simplified
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundColor(.orange)
                    Text("\(guestStats.pending)")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Pending")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                    Text("\(guestStats.approved)")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Approved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                VStack(spacing: 4) {
                    Image(systemName: "person.3.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                    Text("\(guestStats.active)")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Going")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: { showingDashboard = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                        Text("Manage Guests")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                Button(action: { showingAnalytics = true }) {
                    Image(systemName: "chart.bar.fill")
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
        .sheet(isPresented: $showingDashboard) {
            HostApprovalDashboard(party: party)
        }
        .sheet(isPresented: $showingAnalytics) {
            NavigationView {
                VStack {
                    Text("Party Analytics")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding()
                    
                    Text("Analytics coming soon!")
                        .padding()
                    
                    Spacer()
                }
                .navigationBarItems(
                    trailing: Button("Done") {
                        showingAnalytics = false
                    }
                )
            }
        }
    }
} 