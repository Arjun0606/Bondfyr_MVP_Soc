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
                AfterpartyTabView()  // Party discovery is now the main feed
            }
            .tabItem {
                Image(systemName: "dollarsign.circle.fill")
                Text("Party Feed")
            }
            .tag(Tab.partyFeed)
            
            NavigationView {
                PhotoFeedView()
            }
            .tabItem {
                Image(systemName: "camera")
                Text("Daily Photos")
            }
            .tag(Tab.photos)
            
            NavigationView {
                CreateAfterpartyDirectView()  // Direct party creation view
            }
            .tabItem {
                Image(systemName: "plus.circle.fill")
                Text("Host Party")
            }
            .tag(Tab.hostParty)
            
            NavigationView {
                PartyTalkChatView()  // Party-focused chat
            }
            .tabItem {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                Text("Party Talk")
            }
            .tag(Tab.partyTalk)

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
