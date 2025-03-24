//
//  MainTabView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            EventListView()
                .tabItem {
                    Label("Discover", systemImage: "sparkles")
                }

            MyTicketsView()
                .tabItem {
                    Label("Tickets", systemImage: "qrcode")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
        .accentColor(.pink)
    }
}
