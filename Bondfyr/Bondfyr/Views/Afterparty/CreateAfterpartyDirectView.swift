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
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.pink)
                    
                    Text("Host a Paid Party")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Turn your place into a money-making party spot")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)
                
                // Revenue Highlight
                VStack(spacing: 12) {
                    HStack(spacing: 20) {
                        VStack {
                            Text("88%")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Text("You keep")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        VStack {
                            Text("12%")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.pink)
                            Text("Bondfyr fee")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        VStack {
                            Text("$25")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Avg ticket")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                
                // Example earnings
                VStack(spacing: 8) {
                    Text("💰 Potential Earnings")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 4) {
                        Text("20 guests × $25 = $500 gross")
                            .foregroundColor(.gray)
                        Text("Your cut: $440")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                
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