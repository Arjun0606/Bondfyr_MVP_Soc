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
    
    private let eventsCacheKey = "cached_events"
    private let venuesCacheKey = "cached_venues"
    private let lastUpdateTimeKey = "last_cache_update"
    
    private init() {}
    
    // MARK: - Events Caching
    
    // Cache a list of events for offline access
    func cacheEvents(_ events: [Event]) {
        // We need to convert to CachedEvent because Event isn't directly Codable (due to UUID)
        let cachedEvents = events.map { CachedEvent(from: $0) }
        if let encoded = try? JSONEncoder().encode(cachedEvents) {
            UserDefaults.standard.set(encoded, forKey: eventsCacheKey)
            updateLastCacheTime()
        }
    }
    
    // Get cached events
    func getCachedEvents() -> [Event]? {
        guard let data = UserDefaults.standard.data(forKey: eventsCacheKey),
              let cachedEvents = try? JSONDecoder().decode([CachedEvent].self, from: data) else {
            return nil
        }
        
        return cachedEvents.map { $0.toEvent() }
    }
    
    // MARK: - Venues Caching
    
    // Cache venue details with their event IDs
    func cacheVenueInfo(for event: Event) {
        var venuesDict = getVenuesDict()
        
        // Create venue info object
        let venueInfo = VenueInfo(
            name: event.name,
            location: event.location,
            city: event.city,
            mapsURL: event.mapsURL,
            eventId: event.id.uuidString,
            instagramHandle: event.instagramHandle
        )
        
        venuesDict[event.id.uuidString] = venueInfo
        
        if let encoded = try? JSONEncoder().encode(venuesDict) {
            UserDefaults.standard.set(encoded, forKey: venuesCacheKey)
        }
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
            print("Failed to render ticket image")
            return nil
        }
        
        guard let data = uiImage.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert ticket to JPEG")
            return nil
        }
        
        let fileName = "ticket_\(ticket.ticketId).jpg"
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            print("Saved offline ticket to: \(fileURL.path)")
            return fileURL
        } catch {
            print("Error saving offline ticket: \(error)")
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

// Codable version of Event for caching
struct CachedEvent: Codable {
    let id: String
    let firestoreId: String?
    let eventName: String
    let name: String
    let description: String
    let date: String
    let time: String
    let venueLogoImage: String
    let eventPosterImage: String
    let location: String
    let city: String
    let mapsURL: String
    let galleryImages: [String]?
    let instagramHandle: String
    let photoContestActive: Bool
    
    init(from event: Event) {
        self.id = event.id.uuidString
        self.firestoreId = event.firestoreId
        self.eventName = event.eventName
        self.name = event.name
        self.description = event.description
        self.date = event.date
        self.time = event.time
        self.venueLogoImage = event.venueLogoImage
        self.eventPosterImage = event.eventPosterImage
        self.location = event.location
        self.city = event.city
        self.mapsURL = event.mapsURL
        self.galleryImages = event.galleryImages
        self.instagramHandle = event.instagramHandle
        self.photoContestActive = event.photoContestActive
    }
    
    func toEvent() -> Event {
        return Event(
            firestoreId: firestoreId,
            eventName: eventName,
            name: name,
            location: location,
            description: description,
            date: date,
            time: time,
            venueLogoImage: venueLogoImage,
            eventPosterImage: eventPosterImage,
            city: city,
            mapsURL: mapsURL,
            galleryImages: galleryImages,
            instagramHandle: instagramHandle,
            photoContestActive: photoContestActive
        )
    }
}

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
            
            // Ticket details
            VStack(alignment: .leading, spacing: 10) {
                detailRow(title: "Ticket Type", value: ticket.tier)
                detailRow(title: "Date", value: formatDate(ticket.timestamp))
                detailRow(title: "Quantity", value: "\(ticket.count)")
                detailRow(title: "Ticket ID", value: ticket.ticketId)
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
            
            // QR Code for the ticket
            if let qrImage = generateQRCode(from: ticket.ticketId) {
                Image(uiImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .background(Color.white)
                    .cornerRadius(10)
            }
            
            Text("OFFLINE MODE")
                .font(.caption)
                .padding(8)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(4)
        }
        .frame(width: 320, height: 600)
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.pink, Color.purple.opacity(0.8)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(16)
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(.white)
        }
    }
    
    private func formatDate(_ isoDate: String) -> String {
        let dateFormatter = ISO8601DateFormatter()
        if let date = dateFormatter.date(from: isoDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return isoDate
    }
    
    @MainActor
    private func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: .ascii)
        if let qrFilter = CIFilter(name: "CIQRCodeGenerator") {
            qrFilter.setValue(data, forKey: "inputMessage")
            if let qrImage = qrFilter.outputImage {
                let transform = CGAffineTransform(scaleX: 10, y: 10)
                let scaledQrImage = qrImage.transformed(by: transform)
                let context = CIContext()
                guard let cgImage = context.createCGImage(scaledQrImage, from: scaledQrImage.extent) else { return nil }
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
} 