//
//  EventListView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct EventListView: View {
    @State private var selectedCity = "Pune"
    @State private var searchText = ""
    @State private var isOfflineMode = false
    @State private var showOfflineAlert = false
    @State private var lastUpdateTimeString: String = "Never"
    
    let cities = ["Pune", "Mumbai", "Delhi", "Bangalore"]
    
    var filteredEvents: [Event] {
        var events = isOfflineMode ? (OfflineDataManager.shared.getCachedEvents() ?? []) : sampleEvents
        
        if !selectedCity.isEmpty {
            events = events.filter { $0.city == selectedCity }
        }
        
        if !searchText.isEmpty {
            events = events.filter { $0.name.lowercased().contains(searchText.lowercased()) ||
                $0.description.lowercased().contains(searchText.lowercased()) }
        }
        
        return events
    }
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                // Fixed searchbar with city selector
                HStack {
                    // Search icon
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                    
                    // Search field
                    TextField("Search events...", text: $searchText)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // City selector button
                    Menu {
                        ForEach(cities, id: \.self) { city in
                            Button(action: {
                                selectedCity = city
                            }) {
                                Text(city)
                            }
                        }
                    } label: {
                        Text(selectedCity)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.pink)
                            .cornerRadius(20)
                    }
                    .padding(.trailing, 8)
                }
                .frame(height: 50)
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Events list
                ScrollView(showsIndicators: false) {
                    eventsListContent
                }
            }
            .padding(.top, 5)
        }
        .onAppear {
            checkLastUpdateTime()
        }
        .alert(isPresented: $showOfflineAlert) {
            Alert(
                title: Text("No Offline Data"),
                message: Text("You need to cache events before using offline mode. Connect to the internet and tap 'Cache All' to save events for offline use."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    var eventsListContent: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                    
                    Text("Try a different city or search term")
                        .font(.subheadline)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            } else {
                // Show the events for the selected city
                ForEach(filteredEvents) { event in
                    NavigationLink(destination: EventDetailView(event: event)) {
                        EventCardView(event: event)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // Check when the cache was last updated
    private func checkLastUpdateTime() {
        if let lastUpdate = OfflineDataManager.shared.getLastCacheUpdateTime() {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            lastUpdateTimeString = formatter.string(from: lastUpdate)
        } else {
            lastUpdateTimeString = "Never"
        }
    }
}
