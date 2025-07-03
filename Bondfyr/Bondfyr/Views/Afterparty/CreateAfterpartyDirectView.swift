import SwiftUI
import CoreLocation

struct CreateAfterpartyDirectView: View {
    @StateObject private var locationManager = LocationManager()
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showingCreateSheet = false
    @State private var showLocationDeniedAlert = false
    @State private var hasActiveParty = false
    @State private var showingActivePartyAlert = false
    @State private var showingDashboard = false
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("Become a Top Host")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Host exclusive parties. We handle the payments, guests, and ticketing.")
                        .font(.headline)
                        .fontWeight(.regular)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Host Benefits Section
                VStack(spacing: 12) {
                    BenefitRow(icon: "checkmark.shield.fill", text: "Secure Payments Handled")
                    BenefitRow(icon: "person.2.fill", text: "Automated Guest List")
                    BenefitRow(icon: "ticket.fill", text: "Hassle-Free Ticketing")
                    BenefitRow(icon: "chart.pie.fill", text: "You Keep 100% During TestFlight!", isPrimary: true)
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.1))
                .cornerRadius(16)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Create Party Button
                    Button(action: {
                        if hasActiveParty {
                            showingActivePartyAlert = true
                        } else if locationManager.authorizationStatus == .denied {
                            showLocationDeniedAlert = true
                        } else {
                            showingCreateSheet = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create New Party")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            hasActiveParty ? 
                            AnyView(Color.gray) : 
                            AnyView(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
                        )
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .opacity(hasActiveParty ? 0.7 : 1.0)
                    }
                    .disabled(hasActiveParty)
                    
                    // Host Dashboard Button
                    Button(action: {
                        showingDashboard = true
                    }) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                            Text("Host Dashboard")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6).opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal)
                
                if hasActiveParty {
                    Text("You already have an active party")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingCreateSheet) {
            CreateAfterpartyView(
                currentLocation: locationManager.location?.coordinate,
                currentCity: locationManager.currentCity ?? ""
            )
        }
        .sheet(isPresented: $showingDashboard) {
            HostDashboardView()
        }
        .alert("Active Afterparty Exists", isPresented: $showingActivePartyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You already have an active afterparty. Please wait for it to end before creating a new one.")
        }
        .alert("Location Access Required", isPresented: $showLocationDeniedAlert) {
            Button("Open Settings", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable location services in Settings to create parties.")
        }
        .task {
            if let isActive = try? await afterpartyManager.hasActiveAfterparty() {
                hasActiveParty = isActive
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String
    var isPrimary: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isPrimary ? .green : .pink)
                .font(.headline)
            Text(text)
                .foregroundColor(isPrimary ? .green : .white)
                .fontWeight(isPrimary ? .bold : .regular)
            Spacer()
        }
    }
} 