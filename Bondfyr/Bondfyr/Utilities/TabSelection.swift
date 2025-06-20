//
//  TabSelection.swift
//  Bondfyr
//
//  Created by Arjun Varma on 26/03/25.
//

import Foundation

class TabSelection: ObservableObject {
    @Published var selectedTab: Tab = .partyFeed
}

enum Tab: Int, Hashable {
    case partyFeed      // main party discovery and marketplace
    case hostParty      // party creation and host dashboard
    case tickets        // user's purchased tickets and upcoming parties
    case profile        // user profile and settings
}
