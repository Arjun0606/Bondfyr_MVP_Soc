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
                Image(systemName: "flame")
                Text("Hot Venues")
            }
            .tag(Tab.discover)
            
            NavigationView {
                PhotoFeedView()
            }
            .tabItem {
                Image(systemName: "camera")
                Text("Daily Photos")
            }
            .tag(Tab.photos)
            
            NavigationView {
                AfterpartyTabView()
            }
            .tabItem {
                Image(systemName: "party.popper")
                Text("Afterparty")
            }
            .tag(Tab.afterparty)
            
            NavigationView {
                CityChatTabView()
            }
            .tabItem {
                Image(systemName: "bubble.left.and.bubble.right")
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
