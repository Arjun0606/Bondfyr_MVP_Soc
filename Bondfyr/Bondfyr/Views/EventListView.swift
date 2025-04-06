//
//  EventListView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct EventListView: View {
    var events: [Event] = sampleEvents
    
    @State private var selectedCity: String = "All Cities"
    @State private var searchText: String = ""
    
    var cities: [String] {
        var citySet = Set<String>()
        events.forEach { citySet.insert($0.city) }
        return ["All Cities"] + citySet.sorted()
    }
    
    var filteredEvents: [Event] {
        var filtered = events
        
        // Apply city filter
        if selectedCity != "All Cities" {
            filtered = filtered.filter { $0.city == selectedCity }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.name.lowercased().contains(searchText.lowercased()) ||
                $0.location.lowercased().contains(searchText.lowercased()) ||
                $0.description.lowercased().contains(searchText.lowercased())
            }
        }
        
        return filtered
    }
    
    // Group events by city
    var groupedEvents: [String: [Event]] {
        Dictionary(grouping: filteredEvents, by: { $0.city })
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // City selector and search bar
                VStack(spacing: 12) {
                    // City selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(cities, id: \.self) { city in
                                Button(action: {
                                    selectedCity = city
                                }) {
                                    Text(city)
                                        .font(.subheadline)
                                        .fontWeight(selectedCity == city ? .bold : .regular)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedCity == city ? Color.pink : Color.gray.opacity(0.2))
                                        .foregroundColor(.white)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search events...", text: $searchText)
                            .foregroundColor(.white)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .padding(.top)
                .background(Color.black)
                
                // Events list
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if filteredEvents.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.gray)
                                
                                Text("No events found")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                                
                                Text("Try changing your search or filters")
                                    .font(.subheadline)
                                    .foregroundColor(.gray.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 50)
                        } else {
                            if selectedCity == "All Cities" {
                                // Group by city when showing all cities
                                ForEach(groupedEvents.keys.sorted(), id: \.self) { city in
                                    VStack(alignment: .leading) {
                                        Text(city)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal)
                                        
                                        ForEach(groupedEvents[city] ?? []) { event in
                                            NavigationLink(destination: EventDetailView(event: event)) {
                                                EventCardView(event: event)
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                    .padding(.bottom, 20)
                                }
                            } else {
                                // Just show the events for the selected city
                                ForEach(filteredEvents) { event in
                                    NavigationLink(destination: EventDetailView(event: event)) {
                                        EventCardView(event: event)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.top)
                }
            }
        }
    }
}
