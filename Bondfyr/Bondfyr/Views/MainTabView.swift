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
                VenueListView()
            }
            .tabItem {
                Image(systemName: "flame.fill")
                Text("Hot Venues")
            }
            .tag(Tab.discover)
            
            NavigationView {
                AfterpartyTabView()
            }
            .tabItem {
                Image(systemName: "party.popper")
                Text("Afterparty")
            }
            .tag(Tab.afterparty)

            NavigationView {
                PlannerChatView()
            }
            .tabItem {
                Image(systemName: "sparkles")
                Text("Planner")
            }
            .tag(Tab.planner)
            
            NavigationView {
                CityChatTabView()
            }
            .tabItem {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                Text("City Chat")
            }
            .tag(Tab.citychat)

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
    }
}
