//
//  MainTabView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var tabSelection: TabSelection
    
    // CRITICAL FIX: Add state for notification navigation
    @State private var showHostDashboard = false
    @State private var showPartyDetails = false
    @State private var showPartyRating = false
    @State private var navigationPartyId: String?
    @State private var showPartyManagement = false

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
                showPartyDetails = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToPartyRating"))) { notification in
            if let partyId = notification.userInfo?["partyId"] as? String {
                navigationPartyId = partyId
                showPartyRating = true
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
            if let partyId = navigationPartyId {
                NavigationView {
                    VStack(spacing: 20) {
                        Text("🌟 Rate Your Experience")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Rate Party: \(partyId)")
                            .font(.headline)
                        
                        Text("How was the party? Your rating helps the community!")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Close") {
                            showPartyRating = false
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
                                showPartyRating = false
                                navigationPartyId = nil
                            }
                        }
                    }
                }
            }
        }
    }
}
