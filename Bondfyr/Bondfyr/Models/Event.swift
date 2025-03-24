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

let sampleEvents: [Event] = [
    Event(name: "High Spirits", location: "Mundhwa", date: "March 30, 2025", image: "high_spirits"),
    Event(name: "Qora", location: "Koregaon Park", date: "March 27, 2025", image: "qora"),
    Event(name: "Vault", location: "SB Road", date: "March 28, 2025", image: "vault")
]

