import SwiftUI
import FirebaseAuth

struct HostEarningsDashboardView: View {
    @StateObject private var earningsManager = HostEarningsManager.shared
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var hostEarnings: HostEarnings?
    @State private var isLoading = true
    @State private var showingBankSetup = false
    @State private var showingPayoutRequest = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Loading earnings...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .pink))
                    } else if let earnings = hostEarnings {
                        EarningsOverviewCard(earnings: earnings)
                        QuickActionsCard(
                            earnings: earnings,
                            showingBankSetup: $showingBankSetup,
                            showingPayoutRequest: $showingPayoutRequest
                        )
                        RecentTransactionsCard(earnings: earnings)
                        PayoutHistoryCard(earnings: earnings)
                    } else {
                        EmptyEarningsView()
                    }
                }
                .padding()
            }
            .navigationSafeBackground()
            .navigationTitle("💰 Your Earnings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.pink)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task { await loadHostEarnings() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.pink)
                    }
                }
            }
        }
        .sheet(isPresented: $showingBankSetup) {
            HostBankSetupView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showingPayoutRequest) {
            if let earnings = hostEarnings {
                PayoutRequestSheet(earnings: earnings)
            }
        }
        .task {
            await loadHostEarnings()
        }
    }
    
    private func loadHostEarnings() async {
        guard let currentUserId = authViewModel.currentUser?.uid else { return }
        
        isLoading = true
        do {
            hostEarnings = try await earningsManager.getHostEarnings(hostId: currentUserId)
            isLoading = false
        } catch {
            print("🔴 EARNINGS: Error loading host earnings: \(error)")
            isLoading = false
        }
    }
}

// MARK: - Earnings Overview Card
struct EarningsOverviewCard: View {
    let earnings: HostEarnings
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Earnings Overview")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 20) {
                EarningsStatView(
                    title: "Pending",
                    amount: earnings.pendingEarnings,
                    color: .orange,
                    subtitle: "Ready for payout"
                )
                
                EarningsStatView(
                    title: "Total Earned",
                    amount: earnings.totalEarnings,
                    color: .green,
                    subtitle: "All time"
                )
                
                EarningsStatView(
                    title: "Paid Out",
                    amount: earnings.paidEarnings,
                    color: .blue,
                    subtitle: "Last: \(earnings.lastPayoutDate?.formatted(.dateTime.month().day()) ?? "Never")"
                )
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
}

struct EarningsStatView: View {
    let title: String
    let amount: Double
    let color: Color
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text("$\(Int(amount))")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quick Actions Card
struct QuickActionsCard: View {
    let earnings: HostEarnings
    @Binding var showingBankSetup: Bool
    @Binding var showingPayoutRequest: Bool
    
    var canRequestPayout: Bool {
        earnings.pendingEarnings >= 10.0 && earnings.bankAccountSetup
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Actions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 12) {
                if !earnings.bankAccountSetup {
                    EarningsActionButton(
                        title: "Setup Bank Account",
                        subtitle: "Required for payouts",
                        icon: "building.columns",
                        color: .blue,
                        action: { showingBankSetup = true }
                    )
                }
                
                EarningsActionButton(
                    title: "Request Payout",
                    subtitle: canRequestPayout ? "Available: $\(Int(earnings.pendingEarnings))" : "Minimum $10 required",
                    icon: "dollarsign.circle",
                    color: canRequestPayout ? .green : .gray,
                    action: { 
                        if canRequestPayout {
                            showingPayoutRequest = true 
                        }
                    }
                )
                
                EarningsActionButton(
                    title: "Payout Settings",
                    subtitle: "Manage payment preferences",
                    icon: "gearshape",
                    color: .purple,
                    action: { showingBankSetup = true }
                )
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
}

struct EarningsActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
        }
    }
}

// MARK: - Recent Transactions Card
struct RecentTransactionsCard: View {
    let earnings: HostEarnings
    
    private var recentTransactions: [HostTransaction] {
        Array(earnings.transactions.suffix(5).reversed())
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Transactions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(earnings.transactions.count) total")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if recentTransactions.isEmpty {
                Text("No transactions yet")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(recentTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
}

struct TransactionRow: View {
    let transaction: HostTransaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.partyTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text("\(transaction.guestName) • \(transaction.date.formatted(.dateTime.month().day()))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("+$\(Int(transaction.hostEarning))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                Text("($\(Int(transaction.amount)) total)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Payout History Card
struct PayoutHistoryCard: View {
    let earnings: HostEarnings
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Payout History")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            if earnings.payoutHistory.isEmpty {
                Text("No payouts yet")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(earnings.payoutHistory) { payout in
                        PayoutRow(payout: payout)
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
}

struct PayoutRow: View {
    let payout: PayoutRecord
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(payout.payoutMethod.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(payout.payoutDate.formatted(.dateTime.month().day().year()))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(Int(payout.amount))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Text(payout.status.rawValue)
                    .font(.caption)
                    .foregroundColor(payout.status == .completed ? .green : .orange)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State
struct EmptyEarningsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Earnings Yet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Start hosting parties to earn money!\nYou'll receive 80% of each ticket sale.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Bank Setup Sheet
struct BankSetupSheet: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "building.columns")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Setup Bank Account")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("To receive payouts, you'll need to provide your bank account information. This is secure and encrypted.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    Button("Setup via Plaid (Recommended)") {
                        // TODO: Integrate Plaid for bank verification
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Button("Manual Bank Entry") {
                        // TODO: Manual bank form
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Button("Use PayPal") {
                        // TODO: PayPal integration
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Bank Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Payout Request Sheet
struct PayoutRequestSheet: View {
    let earnings: HostEarnings
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Request Payout")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Available: $\(Int(earnings.pendingEarnings))")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("Payouts typically process within 2-3 business days")
                    .foregroundColor(.secondary)
                
                Button("Request $\(Int(earnings.pendingEarnings)) Payout") {
                    // TODO: Process payout request
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Spacer()
            }
            .padding()
            .navigationTitle("Payout Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.pink)
            .foregroundColor(.white)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.black.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
} 