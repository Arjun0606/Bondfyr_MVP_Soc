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
    case partyFeed      // was discover - now main party discovery
    case photos         // unchanged - daily photos
    case hostParty      // was afterparty - now party creation 
    case partyTalk      // was citychat - now party discussion
    case profile        // unchanged
    case tickets        // unused
}
