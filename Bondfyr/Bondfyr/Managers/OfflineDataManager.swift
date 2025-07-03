//
//  OfflineDataManager.swift
//  Bondfyr
//
//  Created by Claude AI on 12/07/25.
//

import Foundation
import SwiftUI

// This class manages offline data storage and retrieval
class OfflineDataManager {
    static let shared = OfflineDataManager()
    
    // Keys for UserDefaults storage
    private let eventsCacheKey = "cached_events"
    private let venuesCacheKey = "cached_venues"
    private let lastUpdateTimeKey = "last_cache_update"
    
    // How long cache is valid (24 hours)
    private let cacheValidityPeriod: TimeInterval = 24 * 60 * 60
    
    private init() {}
    
    // MARK: - Events Caching
    
    // Cache events from EventService
    func cacheEvents(_ events: [Event]) {
        
        // TODO: Update this when Event model is standardized
        /*
        let cachedEvents = events.map { CachedEvent(from: $0) }
        
        if let encoded = try? JSONEncoder().encode(cachedEvents) {
            UserDefaults.standard.set(encoded, forKey: eventsCacheKey)
            updateLastCacheTime()
            
        }
        */
    }
    
    // Get cached events if they're still valid
    func getCachedEvents() -> [Event]? {
        
        return nil
        /*
        // Check if cache is still valid
        guard isCacheValid() else {
            return nil
        }
        
        guard let data = UserDefaults.standard.data(forKey: eventsCacheKey),
              let cachedEvents = try? JSONDecoder().decode([CachedEvent].self, from: data) else {
            return nil
        }
        
        return cachedEvents.map { $0.toEvent() }
        */
    }
    
    // Check if cached data is still valid
    func isCacheValid() -> Bool {
        guard let lastUpdate = getLastCacheUpdateTime() else {
            return false
        }
        
        return Date().timeIntervalSince(lastUpdate) < cacheValidityPeriod
    }
    
    // Return cached events or empty array if cache is invalid
    func getValidCachedEvents() -> [Event] {
        return getCachedEvents() ?? []
    }
    
    // MARK: - Venues Caching
    
    // Cache venue details with their event IDs
    func cacheVenueInfo(for event: Event) {
        
        // TODO: Update this when Event model includes venue details
        /*
        var venuesDict = getVenuesDict()
        
        // Create venue info object
        let venueInfo = VenueInfo(
            name: event.name,
            location: event.venue,
            city: "Pune", // Default for now
            mapsURL: "",  // Not available in current model
            eventId: event.id.uuidString,
            instagramHandle: "" // Not available in current model
        )
        
        venuesDict[event.id.uuidString] = venueInfo
        
        if let encoded = try? JSONEncoder().encode(venuesDict) {
            UserDefaults.standard.set(encoded, forKey: venuesCacheKey)
        }
        */
    }
    
    // Get venue info for a specific event
    func getVenueInfo(for eventId: String) -> VenueInfo? {
        let venuesDict = getVenuesDict()
        return venuesDict[eventId]
    }
    
    private func getVenuesDict() -> [String: VenueInfo] {
        guard let data = UserDefaults.standard.data(forKey: venuesCacheKey),
              let venuesDict = try? JSONDecoder().decode([String: VenueInfo].self, from: data) else {
            return [:]
        }
        return venuesDict
    }
    
    // MARK: - Utility Methods
    
    // Check if we have a working cache
    func hasCachedData() -> Bool {
        return getCachedEvents() != nil
    }
    
    // Update the timestamp of the last cache update
    private func updateLastCacheTime() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastUpdateTimeKey)
    }
    
    // Get time of last cache update
    func getLastCacheUpdateTime() -> Date? {
        let timestamp = UserDefaults.standard.double(forKey: lastUpdateTimeKey)
        if timestamp > 0 {
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
    }
    
    // Clear all cached data
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: eventsCacheKey)
        UserDefaults.standard.removeObject(forKey: venuesCacheKey)
        UserDefaults.standard.removeObject(forKey: lastUpdateTimeKey)
    }
    
    // Generate offline ticket image and save to FileManager
    @MainActor
    func saveOfflineTicket(for ticket: TicketModel) -> URL? {
        let renderer = ImageRenderer(content: TicketOfflineView(ticket: ticket))
        
        guard let uiImage = renderer.uiImage else {
            
            return nil
        }
        
        guard let data = uiImage.jpegData(compressionQuality: 0.8) else {
            
            return nil
        }
        
        let fileName = "ticket_\(ticket.ticketId).jpg"
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            
            return fileURL
        } catch {
            
            return nil
        }
    }
    
    // Generate offline ticket image and save to FileManager asynchronously
    func saveOfflineTicketAsync(for ticket: TicketModel) async -> URL? {
        return await MainActor.run {
            saveOfflineTicket(for: ticket)
        }
    }
    
    // Get the URL for a ticket image if it exists
    func getOfflineTicketURL(for ticketId: String) -> URL? {
        let fileName = "ticket_\(ticketId).jpg"
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return nil
    }
    
    // Helper to get documents directory
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

// MARK: - Support Structures

// Structure to cache venue information
struct VenueInfo: Codable {
    let name: String
    let location: String
    let city: String
    let mapsURL: String
    let eventId: String
    let instagramHandle: String
}

// View for generating offline ticket image
struct TicketOfflineView: View {
    let ticket: TicketModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Venue name
            Text(ticket.event)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Event details
            VStack(alignment: .leading, spacing: 10) {
                Text("Ticket ID: \(ticket.ticketId)")
                Text("Timestamp: \(ticket.timestamp)")
                Text("Tier: \(ticket.tier)")
                Text("Phone: \(ticket.phoneNumber)")
                Text("PR Code: \(ticket.prCode)")
            }
            .font(.headline)
            .foregroundColor(.white)
            
            // QR Code placeholder
            Rectangle()
                .fill(Color.white)
                .frame(width: 150, height: 150)
                .overlay(
                    Text("QR CODE")
                        .font(.caption)
                        .foregroundColor(.black)
                )
            
            Text("Valid for offline use")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(30)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.purple, Color.pink]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .frame(width: 300, height: 400)
    }
} 