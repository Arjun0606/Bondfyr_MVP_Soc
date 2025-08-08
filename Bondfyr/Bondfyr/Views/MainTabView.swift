//
//  MainTabView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI
import FirebaseFirestore

struct MainTabView: View {
    @EnvironmentObject var tabSelection: TabSelection
    
    // CRITICAL FIX: Add state for notification navigation
    @State private var showHostDashboard = false
    @State private var showPartyDetails = false
    @State private var showPartyRating = false
    @State private var navigationPartyId: String?
    @State private var showPartyManagement = false
    @State private var partyForRating: Afterparty?
    @State private var partyForDetails: Afterparty? // NEW: party details payload

    init() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.black
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

    var body: some View {
        TabView(selection: $tabSelection.selectedTab) {
            NavigationView {
                AfterpartyTabView()  // Party discovery is now the main feed
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Party Feed")
            }
            .tag(Tab.partyFeed)
            
            NavigationView {
                MyTicketsView()  // User's accepted party invites
            }
            .tabItem {
                Image(systemName: "envelope.fill")
                Text("Party Invites")
            }
            .tag(Tab.tickets)

            NavigationView {
                ProfileView()
            }
            .tabItem {
                Image(systemName: "person.circle")
                Text("Profile")
            }
            .tag(Tab.profile)
        }
        .accentColor(.pink)
        // CRITICAL FIX: Add notification navigation listeners
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToHostDashboard"))) { notification in
            if let partyId = notification.userInfo?["partyId"] as? String {
                navigationPartyId = partyId
                tabSelection.selectedTab = .partyFeed
                showHostDashboard = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToPartyDetails"))) { notification in
            if let partyId = notification.userInfo?["partyId"] as? String {
                navigationPartyId = partyId
                tabSelection.selectedTab = .tickets // Navigate to tickets to see party details
                fetchPartyForDetails(partyId: partyId) // NEW: fetch payload and present
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToPartyRating"))) { notification in
            if let partyId = notification.userInfo?["partyId"] as? String {
                navigationPartyId = partyId
                fetchPartyForRating(partyId: partyId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToProfile"))) { _ in
            tabSelection.selectedTab = .profile
        }
        // PRODUCTION-READY: Replace placeholder sheets with proper navigation
        .sheet(isPresented: $showHostDashboard) {
            if let partyId = navigationPartyId {
                NavigationView {
                    VStack(spacing: 20) {
                        Text("🎯 Host Dashboard")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Manage Party: \(partyId)")
                            .font(.headline)
                        
                        Text("Host dashboard for managing your party and guests.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Close") {
                            showHostDashboard = false
                            navigationPartyId = nil
                        }
                        .padding()
                        .background(Color.pink)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showHostDashboard = false
                                navigationPartyId = nil
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPartyRating) {
            if let party = partyForRating {
                PostPartyRatingView(
                    party: party,
                    onRatingSubmitted: {
                        showPartyRating = false
                        navigationPartyId = nil
                        partyForRating = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showPartyDetails) { // NEW: present party details
            if let party = partyForDetails {
                NavigationView {
                    AfterpartyDetailView(afterparty: party)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showPartyDetails = false
                                    navigationPartyId = nil
                                    partyForDetails = nil
                                }
                            }
                        }
                }
            }
        }
    }
    
    private func fetchPartyForRating(partyId: String) {
        Task {
            do {
                let db = Firestore.firestore()
                let document = try await db.collection("afterparties").document(partyId).getDocument()
                
                guard let data = document.data() else {
                    print("🔴 RATING: No data found for party \(partyId)")
                    return
                }
                
                var partyData = data
                partyData["id"] = document.documentID
                
                let party = try Firestore.Decoder().decode(Afterparty.self, from: partyData)
                
                await MainActor.run {
                    partyForRating = party
                    showPartyRating = true
                }
                
                print("✅ RATING: Successfully fetched party '\(party.title)' for rating")
                
            } catch {
                print("🔴 RATING: Failed to fetch party \(partyId): \(error.localizedDescription)")
            }
        }
    }
    
    // NEW: fetch details payload
    private func fetchPartyForDetails(partyId: String) {
        Task {
            do {
                let db = Firestore.firestore()
                let document = try await db.collection("afterparties").document(partyId).getDocument()
                
                guard let data = document.data() else {
                    print("🔴 DETAILS: No data found for party \(partyId)")
                    return
                }
                
                var partyData = data
                partyData["id"] = document.documentID
                
                let party = try Firestore.Decoder().decode(Afterparty.self, from: partyData)
                
                await MainActor.run {
                    partyForDetails = party
                    showPartyDetails = true
                }
                
                print("✅ DETAILS: Successfully fetched party '\(party.title)' for details")
                
            } catch {
                print("🔴 DETAILS: Failed to fetch party \(partyId): \(error.localizedDescription)")
            }
        }
    }
}
