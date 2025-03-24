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
    let description: String
    let date: String
    let time: String
    let image: String
    let location: String
    let mapsURL: String
}

let sampleEvents: [Event] = [
    Event(
        name: "High Spirits",
        description: "High Spirits Cafe in Pune, India, is a beloved nightlife hotspot that has been a fixture in Koregaon Park for over a decade. With its inviting open-air setting, adorned with fairy lights, it's a gathering place for both locals and visitors. The venue's eclectic music scene, ranging from live bands to DJ sets, ensures there's always something for every music lover.",
        date: "March 30, 2025",
        time: "9:00 PM onwards",
        image: "high_spirits",
        location: "Mundhwa, Pune",
        mapsURL: "https://maps.app.goo.gl/92DFDF4oRGoVgFPs6?g_st=com.google.maps.preview.copy"
    ),
    Event(
        name: "Qora",
        description: "An elevated cocktail experience accompanied by Contemporary fare! Serving responsibly to individuals aged 25 and above.",
        date: "March 27, 2025",
        time: "8:00 PM onwards",
        image: "qora",
        location: "Koregaon Park, Pune",
        mapsURL: "https://maps.app.goo.gl/PyuS1E19kp38bKwi9?g_st=com.google.maps.preview.copy"
    ),
    Event(
        name: "Vault",
        description: "Dive into the underground, dive into VAULT!🪩 Experience the best night life!✨",
        date: "March 28, 2025",
        time: "10:00 PM onwards",
        image: "vault",
        location: "SB Road, Pune",
        mapsURL: "https://maps.app.goo.gl/B37Ry8uMQueSSAfp7?g_st=com.google.maps.preview.copy"
    )
]

