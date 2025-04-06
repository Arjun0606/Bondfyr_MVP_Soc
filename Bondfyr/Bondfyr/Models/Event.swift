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
    let venueLogoImage: String // used in EventListView
    let eventPosterImage: String // used in EventDetailView top
    let location: String
    let city: String
    let mapsURL: String
    let galleryImages: [String]?
    let instagramHandle: String
}

let sampleEvents: [Event] = [
    Event(
        name: "High Spirits",
        description: "High Spirits Cafe in Pune, India, is a beloved nightlife hotspot that has been a fixture in Koregaon Park for over a decade. With its inviting open-air setting, adorned with fairy lights, it's a gathering place for both locals and visitors. The venue's eclectic music scene, ranging from live bands to DJ sets, ensures there's always something for every music lover.",
        date: "March 30, 2025",
        time: "9:00 PM onwards",
        venueLogoImage: "High_spirits",
        eventPosterImage: "Hs_e",
        location: "Mundhwa, Pune",
        city: "Pune",
        mapsURL: "https://maps.app.goo.gl/92DFDF4oRGoVgFPs6?g_st=com.google.maps.preview.copy",
        galleryImages: ["Hs1", "Hs2", "Hs3"],
        instagramHandle: "thehighspirits"
    ),
    Event(
        name: "Qora",
        description: "An elevated cocktail experience accompanied by Contemporary fare! Serving responsibly to individuals aged 25 and above.",
        date: "March 27, 2025",
        time: "8:00 PM onwards",
        venueLogoImage: "Qora",
        eventPosterImage: "Q_e",
        location: "Koregaon Park, Pune",
        city: "Pune",
        mapsURL: "https://maps.app.goo.gl/PyuS1E19kp38bKwi9?g_st=com.google.maps.preview.copy",
        galleryImages: ["Q1", "Q2", "Q3"],
        instagramHandle: "qora_pune"
    ),
    Event(
        name: "Vault",
        description: "Dive into the underground, dive into VAULT!🪩 Experience the best night life!✨",
        date: "March 28, 2025",
        time: "10:00 PM onwards",
        venueLogoImage: "Vault",
        eventPosterImage: "V_e",
        location: "SB Road, Pune",
        city: "Pune",
        mapsURL: "https://maps.app.goo.gl/B37Ry8uMQueSSAfp7?g_st=com.google.maps.preview.copy",
        galleryImages: ["V1", "V2", "V3"],
        instagramHandle: "vault.pune"
    )
]

