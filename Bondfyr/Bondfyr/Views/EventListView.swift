//
//  EventListView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct EventListView: View {
    let events = [
        Event(name: "High Spirits", location: "Koregaon Park", date: "March 30, 2025", image: "high_spirits"),
        Event(name: "Qora", location: "Baner", date: "April 5, 2025", image: "qora"),
        Event(name: "Vault", location: "Mundhwa", date: "April 13, 2025", image: "vault")
    ]

    var body: some View {
        NavigationView {
            List(events) { event in
                NavigationLink(destination: EventDetailView(event: event)) {
                    HStack(spacing: 12) {
                        Image(event.image)
                            .resizable()
                            .frame(width: 80, height: 80)
                            .cornerRadius(10)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.name)
                                .font(.headline)
                                .foregroundColor(.white)

                            Text(event.location)
                                .font(.subheadline)
                                .foregroundColor(.gray)

                            Text(event.date)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.black)
            }
            .navigationTitle("Events")
            .background(Color.black)
        }
    }
}
