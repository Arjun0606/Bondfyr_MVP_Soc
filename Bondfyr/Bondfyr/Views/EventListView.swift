//
//  EventListView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI
import Combine
import FirebaseFirestore

struct EventListView: View {
    @EnvironmentObject var eventViewModel: EventViewModel
    @State private var searchText = ""
    @State private var selectedCity = "All Cities"
    @State private var showOfflineAlert = false
    @State private var lastUpdateTimeString = "Never"
    @State private var navigateToEventId: String? = nil
    @State private var navigateToGallery = false
    @Environment(\.pendingEventNavigation) var pendingNavigation
    @Environment(\.pendingEventAction) var pendingAction
    
    var filteredEvents: [Event] {
        var events = eventViewModel.events
        
        // Filter by search text
        if !searchText.isEmpty {
            events = events.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
        
        // Filter by city
        if selectedCity != "All Cities" {
            if selectedCity == "Pune" {
                // All current events are in Pune, so no additional filtering needed
                // Do nothing as all current events are already in Pune
            } else {
                // For other cities, we don't have events yet
                events = []
            }
        }
        
        return events
    }
    
    var cities: [String] {
        // Hardcoded list of major Indian cities
        return ["All Cities", "Pune", "Mumbai", "Delhi", "Bangalore", "Chennai", "Hyderabad", "Kolkata", "Ahmedabad", "Jaipur"]
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(red: 0.2, green: 0.08, blue: 0.3)]),
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with title and refresh button
                HStack {
                    Text("Discover")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
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
                
                // City dropdown
                cityDropdown
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                
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
            .onChange(of: pendingNavigation) { eventId in
                handlePendingNavigation(eventId: eventId)
            }
            .onAppear {
                loadEvents()
                checkLastUpdateTime()
                
                // Check if we have pending navigation
                handlePendingNavigation(eventId: pendingNavigation)
            }
            // Add navigation links for programmatic navigation
            .background(
                NavigationLink(
                    destination: pendingNavigationDestination(),
                    isActive: Binding(
                        get: { navigateToEventId != nil },
                        set: { if !$0 { navigateToEventId = nil } }
                    )
                ) {
                    EmptyView()
                }
            )
        }
    }
    
    // Handle pending navigation
    private func handlePendingNavigation(eventId: String?) {
        guard let eventId = eventId else { return }
        
        print("EventListView handling navigation for event: \(eventId)")
        
        // Find the event in the list
        if let event = eventViewModel.events.first(where: { $0.id.uuidString == eventId }) {
            // Set the navigation target
            self.navigateToEventId = eventId
            
            // Check if we should navigate to gallery
            if pendingAction == "showGallery" {
                self.navigateToGallery = true
            } else {
                self.navigateToGallery = false
            }
        } else {
            print("⚠️ Event not found for ID: \(eventId)")
        }
    }
    
    // Determine the navigation destination
    private func pendingNavigationDestination() -> some View {
        Group {
            if let eventId = navigateToEventId,
               let event = eventViewModel.events.first(where: { $0.id.uuidString == eventId }) {
                if navigateToGallery {
                    EventPhotoGalleryView(event: event)
                } else {
                    EventDetailView(event: event)
                }
            } else {
                Text("Event not found")
                    .foregroundColor(.red)
            }
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
    
    private var cityDropdown: some View {
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
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.pink)
                Text(selectedCity)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            }
            .padding(10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
        }
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
