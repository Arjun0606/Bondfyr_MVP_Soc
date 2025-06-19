import SwiftUI

// MARK: - Host Earnings Dashboard
struct HostEarningsDashboardView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    @State private var hostEarnings: HostEarnings?
    @State private var isLoading = true
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else if let earnings = hostEarnings {
                        // MARK: - Total Earnings Header
                        VStack(spacing: 12) {
                            Text("Your Earnings")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("$\(String(format: "%.2f", earnings.totalEarnings))")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            
                            Text("All time earnings")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemGray6).opacity(0.1))
                        .cornerRadius(16)
                        
                        // MARK: - Monthly Earnings
                        HStack(spacing: 16) {
                            VStack {
                                Text("$\(String(format: "%.2f", earnings.thisMonth))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("This Month")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple.opacity(0.3))
                            .cornerRadius(12)
                            
                            VStack {
                                Text("$\(String(format: "%.2f", earnings.lastMonth))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("Last Month")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.pink.opacity(0.3))
                            .cornerRadius(12)
                        }
                        
                        // MARK: - Quick Stats
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Your Stats")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 16) {
                                // Total parties hosted
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(earnings.totalAfterparties)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Text("Parties Hosted")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // Total guests
                                VStack(alignment: .center, spacing: 4) {
                                    Text("\(earnings.totalGuests)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Text("Total Guests")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // Average party size
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(String(format: "%.1f", earnings.averagePartySize))")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Text("Avg Party Size")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6).opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        // MARK: - Pending Payouts
                        if earnings.pendingPayouts > 0 {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Pending Payouts")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("$\(String(format: "%.2f", earnings.pendingPayouts))")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.orange)
                                        Text("Will be transferred to your bank account within 2-3 business days")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Button("View Details") {
                                        // TODO: Navigate to payout details
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        
                        // MARK: - Host Tips
                        VStack(alignment: .leading, spacing: 12) {
                            Text("💡 Host Tips")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            VStack(spacing: 8) {
                                HostTipRow(
                                    icon: "photo.fill",
                                    tip: "Add a cover photo to get 3x more requests",
                                    color: .purple
                                )
                                
                                HostTipRow(
                                    icon: "dollarsign.circle.fill",
                                    tip: "Parties priced $15-25 get the most bookings",
                                    color: .green
                                )
                                
                                HostTipRow(
                                    icon: "person.2.fill",
                                    tip: "Auto-approve increases your booking rate by 40%",
                                    color: .blue
                                )
                                
                                HostTipRow(
                                    icon: "clock.fill",
                                    tip: "Post parties 2-4 hours before start time",
                                    color: .orange
                                )
                            }
                        }
                        
                        // MARK: - Create New Party Button
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                            // TODO: Navigate to create party
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Host Another Party")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                        .padding(.top)
                        
                    } else {
                        // MARK: - No Earnings State
                        VStack(spacing: 20) {
                            Image(systemName: "dollarsign.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            VStack(spacing: 8) {
                                Text("Start Earning with Bondfyr")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("Host your first paid party and start making money from your social events!")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Button("Create Your First Party") {
                                presentationMode.wrappedValue.dismiss()
                                // TODO: Navigate to create party
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .cornerRadius(25)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Earnings")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
        }
        .preferredColorScheme(.dark)
        .task {
            await loadHostEarnings()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadHostEarnings() async {
        guard let hostId = authViewModel.currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let earnings = try await afterpartyManager.getHostEarnings(for: hostId)
            await MainActor.run {
                self.hostEarnings = earnings
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

// MARK: - Host Tip Row Component
struct HostTipRow: View {
    let icon: String
    let tip: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(tip)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview
struct HostEarningsDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        HostEarningsDashboardView()
            .environmentObject(AuthViewModel())
    }
} 