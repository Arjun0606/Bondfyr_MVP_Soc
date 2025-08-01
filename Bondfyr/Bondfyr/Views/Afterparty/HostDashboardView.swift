//
//  HostDashboardView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI
import CoreLocation
import FirebaseFirestore

struct HostDashboardView: View {
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var hostParties: [Afterparty] = []
    @State private var showingCreateSheet = false
    @State private var selectedParty: Afterparty? = nil
    @State private var showingPartyManagement = false
    @State private var showingEarningsDashboard = false
    @State private var isLoading = false
    @State private var error: String? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Loading your parties...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .pink))
                            .safeTopPadding()
                    } else if let error = error {
                        ErrorView(message: error) {
                            Task { await loadHostParties() }
                        }
                    } else {
                        HostStatsSection(parties: hostParties)
                        QuickActionsSection(showingCreateSheet: $showingCreateSheet, showingEarningsDashboard: $showingEarningsDashboard, parties: hostParties)
                        PartiesListSection(
                            parties: hostParties,
                            onManageParty: { party in
                                selectedParty = party
                                showingPartyManagement = true
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationSafeBackground()
            .navigationTitle("Host Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.pink)
                    }
                }
            }
            .refreshable {
                await loadHostParties()
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateAfterpartyView(currentLocation: nil, currentCity: "")
        }
        .sheet(isPresented: $showingPartyManagement) {
            if let party = selectedParty {
                PartyManagementSheet(party: party)
            }
        }
        .sheet(isPresented: $showingEarningsDashboard) {
            HostEarningsDashboardView()
                .environmentObject(authViewModel)
        }
        .task {
            await loadHostParties()
        }
    }
    
    private func loadHostParties() async {
        guard let currentUserId = authViewModel.currentUser?.uid else {
            error = "User not authenticated"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            // Load real parties for the current user
            let parties = try await afterpartyManager.getHostParties(hostId: currentUserId)
            await MainActor.run {
                hostParties = parties
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load parties: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

// MARK: - Error View
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button("Try Again", action: onRetry)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.pink)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .padding()
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
    @Binding var showingEarningsDashboard: Bool
    let parties: [Afterparty]
    
    private var hasActiveParty: Bool {
        let now = Date()
        return parties.contains { party in
                    return now < party.endTime  // Only check actual end time, not creation time
        }
    }
    
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
                        subtitle: hasActiveParty ? "Active party exists" : "Start earning",
                        icon: "plus.circle.fill",
                        color: hasActiveParty ? .gray : .pink,
                        isDisabled: hasActiveParty
                    ) {
                        if !hasActiveParty {
                            showingCreateSheet = true
                        }
                    }
                    
                    ActionCardView(
                        title: "Earnings",
                        subtitle: "Track income",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .green,
                        isDisabled: false
                    ) {
                        // TODO: Show earnings
                    }
                    
                    ActionCardView(
                        title: "Tips",
                        subtitle: "Host better",
                        icon: "lightbulb.fill",
                        color: .orange,
                        isDisabled: false
                    ) {
                        // TODO: Show tips
                    }
                    
                    ActionCardView(
                        title: "Bank Setup",
                        subtitle: "Configure payouts",
                        icon: "building.columns.fill",
                        color: .blue,
                        isDisabled: false
                    ) {
                        openDodoMerchantOnboarding()
                    }
                    
                    ActionCardView(
                        title: "Your Earnings",
                        subtitle: "View payments & payouts",
                        icon: "dollarsign.circle.fill",
                        color: .green,
                        isDisabled: false
                    ) {
                        showingEarningsDashboard = true
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
    
    private func openDodoMerchantOnboarding() {
        // Open Dodo's hosted merchant onboarding flow
        guard let url = URL(string: "https://dashboard.dodopayments.com/onboarding") else { return }
        UIApplication.shared.open(url)
    }
}

struct ActionCardView: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isDisabled ? .gray : color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isDisabled ? .gray : .white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding()
            .frame(width: 120, height: 100)
            .background(Color(.systemGray6).opacity(isDisabled ? 0.05 : 0.1))
            .cornerRadius(12)
        }
        .disabled(isDisabled)
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
    @State private var partyState: Afterparty?
    
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
            FixedGuestListView(partyId: party.id, originalParty: party)
        }
        .onAppear {
            partyState = party
        }
        .sheet(isPresented: $showingEditSheet) {
            EditAfterpartyView(afterparty: party)
        }
        .alert("End Party?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Party", role: .destructive) {
                Task {
                    await deleteParty()
                }
            }
        } message: {
            Text("This will mark your party as ended. Guests will be notified.")
        }
    }
    
    private func deleteParty() async {
        do {
            let afterpartyManager = AfterpartyManager.shared
            try await afterpartyManager.deleteAfterparty(party)
            await MainActor.run {
                presentationMode.wrappedValue.dismiss()
            }
        } catch {
            
        }
    }
}

// MARK: - Party Overview Section
struct PartyOverviewSection: View {
    let party: Afterparty
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Party Header
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
            .padding()
            .background(Color(.systemGray6).opacity(0.1))
            .cornerRadius(12)
        }
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
                title: "Bondfyr Fee (20%):",
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
        party.guestRequests.filter { $0.approvalStatus == .pending }.count
    }
    
    private var approvedCount: Int {
        party.guestRequests.filter { $0.approvalStatus == .approved }.count
    }
    
    private var guestListSubtitle: String {
        if pendingCount > 0 && approvedCount > 0 {
            return "\(approvedCount) approved, \(pendingCount) pending"
        } else if pendingCount > 0 {
            return "\(pendingCount) pending requests"
        } else if approvedCount > 0 {
            return "\(approvedCount) approved guests"
        } else {
            return "No requests yet"
        }
    }
    
    // End Party Logic - matches main party card implementation
    private var canEndParty: Bool {
        let oneHourAfterStart = party.startTime.addingTimeInterval(3600) // 1 hour = 3600 seconds
        return Date() >= oneHourAfterStart
    }
    
    private var timeUntilEndEnabled: String {
        let oneHourAfterStart = party.startTime.addingTimeInterval(3600)
        let timeRemaining = oneHourAfterStart.timeIntervalSinceNow
        
        if timeRemaining <= 0 {
            return ""
        } else if timeRemaining < 3600 {
            return "\(Int(timeRemaining/60))m"
        } else {
            return "\(Int(timeRemaining/3600))h \(Int((timeRemaining.truncatingRemainder(dividingBy: 3600))/60))m"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ActionRowView(
                title: "Guest Management",
                subtitle: guestListSubtitle,
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
                title: canEndParty ? "End Party" : "End Party",
                subtitle: canEndParty ? "Complete the party" : "Available in \(timeUntilEndEnabled)",
                icon: canEndParty ? "stop.circle" : "clock.fill",
                color: canEndParty ? .red : .gray,
                isDisabled: !canEndParty
            ) {
                if canEndParty {
                    showingDeleteAlert = true
                }
            }
        }
    }
}

struct ActionRowView: View {
    let title: String
    let subtitle: String
    let icon: String
    var color: Color = .white
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isDisabled ? .gray : (color == .white ? .pink : color))
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isDisabled ? .gray : color)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemGray6).opacity(isDisabled ? 0.05 : 0.1))
            .cornerRadius(12)
        }
        .disabled(isDisabled)
    }
} 