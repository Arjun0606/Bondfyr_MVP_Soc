import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

class EventViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isOnline = true
    
    private var cancellables = Set<AnyCancellable>()
    private let networkMonitor = NetworkMonitor.shared
    
    init() {
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isOnline = isConnected
                
                // If we just came back online, refresh events
                if isConnected {
                    self?.fetchEvents()
                }
            }
            .store(in: &cancellables)
    }
    
    func fetchEvents() {
        isLoading = true
        errorMessage = nil
        
        // Check if we're offline
        if !isOnline {
            loadOfflineEvents()
            return
        }
        
        // Fetch from Firestore
        EventService.shared.fetchEvents { [weak self] events, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    
                    self.errorMessage = "Failed to load events: \(error.localizedDescription)"
                    self.loadOfflineEvents()
                    return
                }
                
                if let events = events {
                    self.events = events
                    
                    // Cache for offline use
                    OfflineDataManager.shared.cacheEvents(events)
                    
                    // Cache venue info for each event
                    for event in events {
                        OfflineDataManager.shared.cacheVenueInfo(for: event)
                    }
                } else {
                    self.loadOfflineEvents()
                }
            }
        }
    }
    
    func fetchEvent(id: String, completion: @escaping (Event?) -> Void) {
        // Check if we already have this event loaded
        if let event = events.first(where: { $0.id.uuidString == id }) {
            completion(event)
            return
        }
        
        // Check if we're offline
        if !isOnline {
            if let cachedEvents = OfflineDataManager.shared.getCachedEvents(),
               let event = cachedEvents.first(where: { $0.id.uuidString == id }) {
                completion(event)
            } else {
                completion(nil)
            }
            return
        }
        
        // Fetch from Firestore
        EventService.shared.fetchEvent(id: id) { event, error in
            DispatchQueue.main.async {
                if let event = event {
                    // Cache this event for offline use
                    OfflineDataManager.shared.cacheVenueInfo(for: event)
                }
                completion(event)
            }
        }
    }
    
    private func loadOfflineEvents() {
        if let cachedEvents = OfflineDataManager.shared.getCachedEvents() {
            events = cachedEvents
            isLoading = false
        } else {
            // Do NOT use sampleEvents in production!
            events = []
            isLoading = false
            errorMessage = "No events available offline. Please connect to the internet."
        }
    }
    
    // Toggle photo contest status
    func togglePhotoContest(eventId: String, active: Bool, completion: @escaping (Bool) -> Void) {
        guard !eventId.isEmpty, isOnline else {
            completion(false)
            return
        }
        
        EventService.shared.togglePhotoContest(eventId: eventId, active: active) { success, error in
            DispatchQueue.main.async {
                if success {
                    // Update the local event
                    if let index = self.events.firstIndex(where: { $0.id.uuidString == eventId }) {
                        // Photo contest status update would need to be handled differently
                        // since Event model doesn't have photoContestActive property
                        
                    }
                }
                
                completion(success)
            }
        }
    }
}

// Network monitoring class
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    @Published var isConnected = true
    
    private init() {
        // In a real implementation, you would use NWPathMonitor
        // For simplicity, we're assuming we're connected
        isConnected = true
    }
    
    func startMonitoring() {
        // In a real implementation, this would start the NWPathMonitor
    }
    
    func stopMonitoring() {
        // In a real implementation, this would stop the NWPathMonitor
    }
} 