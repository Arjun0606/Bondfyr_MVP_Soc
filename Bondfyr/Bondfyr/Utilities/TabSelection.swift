//
//  TabSelection.swift
//  Bondfyr
//
//  Created by Arjun Varma on 26/03/25.
//

import Foundation

class TabSelection: ObservableObject {
    @Published var selectedTab: Tab = .discover
}

enum Tab: Int, Hashable {
    case discover
    case chat
    case tickets
    case profile
}
