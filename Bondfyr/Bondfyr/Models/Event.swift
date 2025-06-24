//
//  Event.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import Foundation

struct Event: Identifiable, Codable {
    var id: UUID
    var name: String
    var date: String
    var time: String
    var venue: String
    var description: String
    var hostId: String // Added hostId
    var host: String
    var coverPhoto: String
    var ticketTiers: [TicketTier]
    var venueLogoImage: String

    struct TicketTier: Identifiable, Codable {
        var id: UUID
        var name: String
        var price: Double
        var quantity: Int
    }
}

let sampleEvents: [Event] = [
    Event(
        id: UUID(),
        name: "The Big Fete",
        date: "March 30, 2025",
        time: "9:00 PM onwards",
        venue: "High Spirits - Koregaon Park",
        description: "High Spirits Cafe in Pune, India, is a beloved nightlife hotspot that has been a fixture in Koregaon Park for over a decade. With its inviting open-air setting, adorned with fairy lights, it's a gathering place for both locals and visitors. The venue's eclectic music scene, ranging from live bands to DJ sets, ensures there's always something for every music lover.",
        hostId: "host1",
        host: "High Spirits",
        coverPhoto: "Hs_e",
        ticketTiers: [
            Event.TicketTier(id: UUID(), name: "General Entry", price: 500.0, quantity: 100)
        ],
        venueLogoImage: "High_spirits"
    ),
    Event(
        id: UUID(),
        name: "Mixology Night",
        date: "March 27, 2025",
        time: "8:00 PM onwards",
        venue: "Qora - Kalyani Nagar",
        description: "An elevated cocktail experience accompanied by Contemporary fare! Serving responsibly to individuals aged 25 and above.",
        hostId: "host2",
        host: "Qora",
        coverPhoto: "Q_e",
        ticketTiers: [
            Event.TicketTier(id: UUID(), name: "VIP Access", price: 800.0, quantity: 50)
        ],
        venueLogoImage: "Qora"
    ),
    Event(
        id: UUID(),
        name: "Underground Beats",
        date: "March 28, 2025",
        time: "10:00 PM onwards",
        venue: "Vault - Baner",
        description: "Dive into the underground, dive into VAULT!🪩 Experience the best night life!✨",
        hostId: "host3",
        host: "Vault",
        coverPhoto: "V_e",
        ticketTiers: [
            Event.TicketTier(id: UUID(), name: "Dance Floor", price: 600.0, quantity: 75)
        ],
        venueLogoImage: "Vault"
    )
]

