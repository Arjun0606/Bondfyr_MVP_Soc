//
//  EventListView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct EventListView: View {
    @EnvironmentObject var eventViewModel: EventViewModel
    @State private var selectedCity = "Pune"
    @State private var searchText = ""
    @State private var showOfflineAlert = false
    @State private var lastUpdateTimeString: String = "Never"
    @State private var showCityDropdown = false
    
    let cities = ["Pune", "Mumbai", "Delhi", "Bangalore"]
    
    var filteredEvents: [Event] {
        var events = eventViewModel.events
        
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
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.purple.opacity(0.8)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Top navigation bar with dropdown
                HStack {
                    Text("Events")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // City dropdown menu
                    Menu {
                        ForEach(cities, id: \.self) { city in
                            Button(action: {
                                selectedCity = city
                            }) {
                                HStack {
                                    Text(city)
                                    if selectedCity == city {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedCity)
                                .foregroundColor(.white)
                            Image(systemName: "chevron.down")
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.pink)
                        .cornerRadius(20)
                    }
                    
                    // Refresh button
                    Button(action: {
                        loadEvents()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Search bar
                searchBar
                    .padding()
                
                // Offline indicator
                if !eventViewModel.isOnline {
                    offlineIndicator
                }
                
                // Events list
                if eventViewModel.isLoading {
                    loadingView
                } else if let error = eventViewModel.errorMessage {
                    errorView(error)
                } else if filteredEvents.isEmpty {
                    emptyStateView
                } else {
                    eventsList
                }
            }
            .alert(isPresented: $showOfflineAlert) {
                Alert(
                    title: Text("Offline Mode"),
                    message: Text("You're viewing cached data from \(lastUpdateTimeString). Connect to internet to see the latest events."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onAppear {
            loadEvents()
            checkLastUpdateTime()
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search events", text: $searchText)
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
        .padding(10)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            Text("Loading events...")
                .foregroundColor(.white)
                .padding()
            Spacer()
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
                .padding()
            Text(message)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding()
            Button("Try Again") {
                loadEvents()
            }
            .padding()
            .background(Color.pink)
            .foregroundColor(.white)
            .cornerRadius(10)
            Spacer()
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(.gray)
                .padding()
            Text("No events found for \(selectedCity)")
                .foregroundColor(.white)
                .padding()
            Spacer()
        }
    }
    
    private var eventsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredEvents) { event in
                    NavigationLink(destination: EventDetailView(event: event)) {
                        EventCard(event: event)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top)
    }
    
    private var offlineIndicator: some View {
        Button(action: {
            showOfflineAlert = true
        }) {
            HStack {
                Image(systemName: "wifi.slash")
                Text("Offline Mode")
                Text("·")
                Text("Last update: \(lastUpdateTimeString)")
            }
            .font(.caption)
            .foregroundColor(.white)
            .padding(8)
            .background(Color.red.opacity(0.8))
            .cornerRadius(5)
        }
        .padding(.bottom, 8)
    }
    
    private func loadEvents() {
        eventViewModel.fetchEvents()
        checkLastUpdateTime()
    }
    
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
