//
//  Event.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import Foundation

struct Event: Identifiable {
    let id = UUID()
    let name: String
    let location: String
    let date: String
    let image: String
}
