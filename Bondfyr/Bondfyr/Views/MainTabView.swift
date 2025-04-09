//
//  MainTabView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var tabSelection: TabSelection

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
                EventListView()
            }
            .tabItem {
                Image(systemName: "sparkles")
                Text("Discover")
            }
            .tag(Tab.discover)
            
            NavigationView {
                CityChatListView()
            }
            .tabItem {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                Text("Chat")
            }
            .tag(Tab.chat)

            MyTicketsView()
                .tabItem {
                    Image(systemName: "qrcode.viewfinder")
                    Text("Tickets")
                }
                .tag(Tab.tickets)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
                .tag(Tab.profile)
        }
        .accentColor(.pink)
    }
}
