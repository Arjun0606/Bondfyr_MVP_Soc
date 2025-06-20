import SwiftUI
import CoreLocation
import FirebaseFirestore

struct HostDashboardView: View {
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var hostParties: [Afterparty] = []
    @State private var showingCreateSheet = false
    @State private var selectedParty: Afterparty? = nil
    @State private var showingPartyManagement = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    HostStatsSection(parties: hostParties)
                    QuickActionsSection(showingCreateSheet: $showingCreateSheet)
                    PartiesListSection(
                        parties: hostParties,
                        onManageParty: { party in
                            selectedParty = party
                            showingPartyManagement = true
                        }
                    )
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Host Dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateAfterpartyView(currentLocation: nil, currentCity: "")
        }
        .sheet(isPresented: $showingPartyManagement) {
            if let party = selectedParty {
                PartyManagementSheet(party: party)
            }
        }
        .task {
            loadSampleData()
        }
    }
    
    private func loadSampleData() {
        hostParties = createSampleHostParties()
    }
    
    private func createSampleHostParties() -> [Afterparty] {
        let now = Date()
        let calendar = Calendar.current
        
        let party = Afterparty(
            id: "host-party-1",
            userId: authViewModel.currentUser?.uid ?? "demo-user",
            hostHandle: "you",
            coordinate: CLLocationCoordinate2D(latitude: 18.4955, longitude: 73.9040),
            radius: 1000,
            startTime: calendar.date(byAdding: .hour, value: 3, to: now) ?? now,
            endTime: calendar.date(byAdding: .hour, value: 7, to: now) ?? now,
            city: "Pune",
            locationName: "Your Rooftop Party",
            description: "Your awesome rooftop party with city views!",
            address: "Your Address, Pune",
            googleMapsLink: "https://maps.google.com",
            vibeTag: "Rooftop, Music, Dancing",
            activeUsers: Array(1...12).map { "guest-\($0)" },
            pendingRequests: ["pending-1", "pending-2"],
            createdAt: calendar.date(byAdding: .hour, value: -1, to: now) ?? now,
            title: "🎉 My Epic Rooftop Bash",
            ticketPrice: 35.0,
            coverPhotoURL: nil,
            maxGuestCount: 50,
            visibility: .publicFeed,
            approvalType: .manual,
            ageRestriction: 21,
            maxMaleRatio: 0.6,
            legalDisclaimerAccepted: true,
            guestRequests: [
                GuestRequest(userId: "pending-1", userName: "Alex K", userHandle: "alex_k", requestedAt: now, paymentStatus: .pending),
                GuestRequest(userId: "pending-2", userName: "Sarah M", userHandle: "sarah_m", requestedAt: calendar.date(byAdding: .minute, value: -10, to: now) ?? now, paymentStatus: .paid)
            ]
        )
        
        return [party]
    }
}

// MARK: - Host Stats Section
struct HostStatsSection: View {
    let parties: [Afterparty]
    
    var body: some View {
        VStack(spacing: 16) {
            StatsHeaderCard(parties: parties)
            StatsDetailRow(parties: parties)
        }
    }
}

struct StatsHeaderCard: View {
    let parties: [Afterparty]
    
    private var totalEarnings: Int {
        Int(parties.reduce(0) { $0 + $1.hostEarnings })
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Earnings")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("$\(totalEarnings)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
    }
}

struct StatsDetailRow: View {
    let parties: [Afterparty]
    
    private var activeCount: Int {
        parties.filter { $0.startTime > Date() }.count
    }
    
    private var totalGuests: Int {
        parties.reduce(0) { $0 + $1.confirmedGuestsCount }
    }
    
    var body: some View {
        HStack(spacing: 32) {
            StatItemView(value: "\(activeCount)", label: "Active")
            StatItemView(value: "\(totalGuests)", label: "Guests")
            StatItemView(value: "\(parties.count)", label: "Total")
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
    }
}

struct StatItemView: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Quick Actions Section
struct QuickActionsSection: View {
    @Binding var showingCreateSheet: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ActionCardView(
                        title: "Create Party",
                        subtitle: "Start earning",
                        icon: "plus.circle.fill",
                        color: .pink
                    ) {
                        showingCreateSheet = true
                    }
                    
                    ActionCardView(
                        title: "Earnings",
                        subtitle: "Track income",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .green
                    ) {
                        // TODO: Show earnings
                    }
                    
                    ActionCardView(
                        title: "Tips",
                        subtitle: "Host better",
                        icon: "lightbulb.fill",
                        color: .orange
                    ) {
                        // TODO: Show tips
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

struct ActionCardView: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding()
            .frame(width: 120, height: 100)
            .background(Color(.systemGray6).opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// MARK: - Parties List Section
struct PartiesListSection: View {
    let parties: [Afterparty]
    let onManageParty: (Afterparty) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if parties.isEmpty {
                EmptyPartiesView()
            } else {
                PartiesHeaderView()
                PartiesContentView(parties: parties, onManageParty: onManageParty)
            }
        }
    }
}

struct EmptyPartiesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 60))
                .foregroundColor(.pink)
            
            Text("No parties yet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Create your first party to start earning!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct PartiesHeaderView: View {
    var body: some View {
        Text("Your Parties")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.white)
    }
}

struct PartiesContentView: View {
    let parties: [Afterparty]
    let onManageParty: (Afterparty) -> Void
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(parties) { party in
                SimplePartyCard(party: party, onManage: { onManageParty(party) })
            }
        }
    }
}

// MARK: - Simple Party Card
struct SimplePartyCard: View {
    let party: Afterparty
    let onManage: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PartyCardHeaderSection(party: party)
            PartyCardStatsSection(party: party)
            PartyCardActionButton(onManage: onManage)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
    }
}

struct PartyCardHeaderSection: View {
    let party: Afterparty
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(party.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("at \(party.locationName)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("$\(Int(party.hostEarnings))")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.green)
        }
    }
}

struct PartyCardStatsSection: View {
    let party: Afterparty
    
    private var pendingCount: Int {
        party.guestRequests.filter { $0.paymentStatus == .pending }.count
    }
    
    var body: some View {
        HStack(spacing: 24) {
            StatItemView(value: "\(party.confirmedGuestsCount)", label: "Guests")
            StatItemView(value: "\(pendingCount)", label: "Pending")
            StatItemView(value: party.timeUntilStart, label: "Starts")
        }
    }
}

struct PartyCardActionButton: View {
    let onManage: () -> Void
    
    var body: some View {
        Button(action: onManage) {
            HStack {
                Image(systemName: "gear")
                Text("Manage Party")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

// MARK: - Party Management Sheet
struct PartyManagementSheet: View {
    let party: Afterparty
    @Environment(\.presentationMode) var presentationMode
    @State private var showingGuestList = false
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    PartyOverviewSection(party: party)
                    ManagementActionsSection(
                        party: party,
                        showingGuestList: $showingGuestList,
                        showingEditSheet: $showingEditSheet,
                        showingDeleteAlert: $showingDeleteAlert
                    )
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Manage Party")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
        }
        .sheet(isPresented: $showingGuestList) {
            GuestListView(afterparty: party)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditAfterpartyView(afterparty: party)
        }
        .alert("Cancel Party?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // TODO: Delete party
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("This will cancel your party and refund all guests.")
        }
    }
}

struct PartyOverviewSection: View {
    let party: Afterparty
    
    var body: some View {
        VStack(spacing: 16) {
            PartyOverviewHeader(party: party)
            PartyEarningsBreakdown(party: party)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
    }
}

struct PartyOverviewHeader: View {
    let party: Afterparty
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(party.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("at \(party.locationName)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("$\(Int(party.ticketPrice))")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.pink)
        }
    }
}

struct PartyEarningsBreakdown: View {
    let party: Afterparty
    
    private var totalRevenue: Double {
        return party.hostEarnings + party.bondfyrRevenue
    }
    
    var body: some View {
        VStack(spacing: 8) {
            EarningsRow(
                title: "Total Revenue:",
                amount: Int(totalRevenue),
                color: .white
            )
            
            EarningsRow(
                title: "Bondfyr Fee (12%):",
                amount: -Int(party.bondfyrRevenue),
                color: .red
            )
            
            Divider().background(Color.gray)
            
            EarningsRow(
                title: "Your Earnings:",
                amount: Int(party.hostEarnings),
                color: .green,
                isTotal: true
            )
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.2))
        .cornerRadius(12)
    }
}

struct EarningsRow: View {
    let title: String
    let amount: Int
    let color: Color
    var isTotal: Bool = false
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            Text(amount >= 0 ? "$\(amount)" : "-$\(abs(amount))")
                .font(isTotal ? .title2 : .body)
                .fontWeight(isTotal ? .bold : .semibold)
                .foregroundColor(color)
        }
    }
}

struct ManagementActionsSection: View {
    let party: Afterparty
    @Binding var showingGuestList: Bool
    @Binding var showingEditSheet: Bool
    @Binding var showingDeleteAlert: Bool
    
    private var pendingCount: Int {
        party.guestRequests.filter { $0.paymentStatus == .pending }.count
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ActionRowView(
                title: "Guest List",
                subtitle: "\(party.confirmedGuestsCount) confirmed, \(pendingCount) pending",
                icon: "person.2.fill"
            ) {
                showingGuestList = true
            }
            
            ActionRowView(
                title: "Edit Party",
                subtitle: "Update details and settings",
                icon: "pencil"
            ) {
                showingEditSheet = true
            }
            
            ActionRowView(
                title: "Share Party",
                subtitle: "Invite more guests",
                icon: "square.and.arrow.up"
            ) {
                // TODO: Share functionality
            }
            
            ActionRowView(
                title: "Cancel Party",
                subtitle: "Refund all guests",
                icon: "xmark.circle",
                color: .red
            ) {
                showingDeleteAlert = true
            }
        }
    }
}

struct ActionRowView: View {
    let title: String
    let subtitle: String
    let icon: String
    var color: Color = .white
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color == .white ? .pink : color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(color)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.1))
            .cornerRadius(12)
        }
    }
} 