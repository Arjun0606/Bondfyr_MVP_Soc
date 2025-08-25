//
//  DemoDataManager.swift
//  Bondfyr
//
//  Created by Claude AI on 18/08/25.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

class DemoDataManager {
    static let shared = DemoDataManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Demo Mode Check
    
    var isDemoMode: Bool {
        return UserDefaults.standard.bool(forKey: "isDemoMode")
    }
    
    // MARK: - Demo Parties
    
    func createDemoParties() async {
        guard isDemoMode else { 
            print("🎭 Demo mode not enabled, skipping party creation")
            return 
        }
        
        // Wait for user authentication to be confirmed with limited retries
        var retryCount = 0
        let maxRetries = 5
        
        while Auth.auth().currentUser == nil && retryCount < maxRetries {
            print("🎭 No authenticated user for demo parties, retrying in 2 seconds... (\(retryCount + 1)/\(maxRetries))")
            try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
            retryCount += 1
        }
        
        guard Auth.auth().currentUser != nil else {
            print("🎭 Failed to get authenticated user after \(maxRetries) retries, skipping demo party creation")
            return
        }
        
        print("🎭 Creating demo parties for App Store reviewers...")
        
        // Clear any existing demo parties first
        await clearExistingDemoParties()
        
        let demoParties = generateDemoParties()
        
        for party in demoParties {
            do {
                try await db.collection("afterparties").document(party["id"] as! String).setData(party)
                print("✅ Created demo party: \(party["title"] as! String)")
            } catch {
                print("❌ Error creating demo party: \(error)")
            }
        }
        
        print("🎉 Demo parties creation completed! Total: \(demoParties.count)")
    }
    
    private func clearExistingDemoParties() async {
        do {
            let snapshot = try await db.collection("afterparties").whereField("isDemoData", isEqualTo: true).getDocuments()
            for document in snapshot.documents {
                try await document.reference.delete()
                print("🗑️ Cleared existing demo party: \(document.documentID)")
            }
        } catch {
            print("❌ Error clearing existing demo parties: \(error)")
        }
    }
    
    private func generateDemoParties() -> [[String: Any]] {
        let demoUserId = Auth.auth().currentUser?.uid ?? "demo-user"
        let baseDate = Date()
        let sfCoordinate = GeoPoint(latitude: 37.7749, longitude: -122.4194)
        
        return [
            // Tonight's party
            [
                "id": "demo-party-1",
                "userId": "demo-host-1",
                "hostHandle": "alex_johnson",
                "coordinate": sfCoordinate,
                "radius": 500.0,
                "startTime": Calendar.current.date(byAdding: .hour, value: 3, to: baseDate) ?? baseDate,
                "endTime": Calendar.current.date(byAdding: .hour, value: 9, to: baseDate) ?? baseDate,
                "city": "San Francisco",
                "locationName": "Downtown Lounge",
                "description": "Join us for an amazing Friday night with great music, drinks, and company! Perfect way to kick off the weekend.",
                "address": "123 Party St, San Francisco, CA",
                "googleMapsLink": "https://maps.google.com/?q=123+Party+St+San+Francisco",
                "vibeTag": "🎉 Energetic",
                "activeUsers": ["user1", "user2", "user3"],
                "pendingRequests": ["user4", "user5"],
                "createdAt": Calendar.current.date(byAdding: .hour, value: -2, to: baseDate) ?? baseDate,
                "title": "Friday Night Vibes 🎉",
                "ticketPrice": 15.0,
                "coverPhotoURL": "",
                "maxGuestCount": 25,
                "visibility": "public",
                "approvalType": "manual",
                "ageRestriction": 21,
                "maxMaleRatio": 0.6,
                "legalDisclaimerAccepted": true,
                "guestRequests": [],
                "earnings": 0.0,
                "bondfyrFee": 0.0,
                "isDemoData": true
            ],
            
            // Rooftop party
            [
                "id": "demo-party-2",
                "userId": "demo-host-2",
                "hostHandle": "emma_chen",
                "coordinate": sfCoordinate,
                "radius": 300.0,
                "startTime": Calendar.current.date(byAdding: .hour, value: 5, to: baseDate) ?? baseDate,
                "endTime": Calendar.current.date(byAdding: .hour, value: 10, to: baseDate) ?? baseDate,
                "city": "San Francisco",
                "locationName": "Sky Terrace",
                "description": "Chill rooftop gathering with sunset views, acoustic music, and craft cocktails. Bring good vibes only!",
                "address": "456 Sky View Ave, San Francisco, CA",
                "googleMapsLink": "https://maps.google.com/?q=456+Sky+View+Ave+San+Francisco",
                "vibeTag": "🌅 Chill",
                "activeUsers": ["user6", "user7"],
                "pendingRequests": ["user8"],
                "createdAt": Calendar.current.date(byAdding: .hour, value: -1, to: baseDate) ?? baseDate,
                "title": "Rooftop Sunset Session 🌅",
                "ticketPrice": 25.0,
                "coverPhotoURL": "",
                "maxGuestCount": 15,
                "visibility": "public",
                "approvalType": "manual",
                "ageRestriction": 25,
                "maxMaleRatio": 0.5,
                "legalDisclaimerAccepted": true,
                "guestRequests": [],
                "earnings": 0.0,
                "bondfyrFee": 0.0,
                "isDemoData": true
            ],
            
            // Demo user's hosted party
            [
                "id": "demo-party-host",
                "userId": demoUserId,
                "hostHandle": "demo_user",
                "coordinate": sfCoordinate,
                "radius": 200.0,
                "startTime": Calendar.current.date(byAdding: .day, value: 2, to: baseDate) ?? baseDate,
                "endTime": Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.date(byAdding: .hour, value: 6, to: baseDate) ?? baseDate) ?? baseDate,
                "city": "San Francisco",
                "locationName": "Demo Gaming Lounge",
                "description": "Gaming tournament with pizza, prizes, and plenty of laughs! All skill levels welcome.",
                "address": "Demo Location, San Francisco, CA",
                "googleMapsLink": "https://maps.google.com/?q=Demo+Location+San+Francisco",
                "vibeTag": "🎮 Gaming",
                "activeUsers": ["demo-confirmed-1"],
                "pendingRequests": ["demo-pending-1", "demo-pending-2"],
                "createdAt": baseDate,
                "title": "Demo Host's Game Night 🎮",
                "ticketPrice": 20.0,
                "coverPhotoURL": "",
                "maxGuestCount": 12,
                "visibility": "public",
                "approvalType": "manual",
                "ageRestriction": 18,
                "maxMaleRatio": 0.7,
                "legalDisclaimerAccepted": true,
                "guestRequests": [],
                "earnings": 20.0,
                "bondfyrFee": 5.0,
                "isDemoData": true
            ],
            
            // Wine tasting party
            [
                "id": "demo-party-3",
                "userId": "demo-host-3",
                "hostHandle": "sophia_wine",
                "coordinate": sfCoordinate,
                "radius": 400.0,
                "startTime": Calendar.current.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate,
                "endTime": Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.date(byAdding: .hour, value: 4, to: baseDate) ?? baseDate) ?? baseDate,
                "city": "San Francisco",
                "locationName": "Elegant Wine Bar",
                "description": "Sophisticated wine tasting with professional sommelier. Learn about different regions while meeting fellow wine enthusiasts.",
                "address": "789 Wine St, San Francisco, CA",
                "googleMapsLink": "https://maps.google.com/?q=789+Wine+St+San+Francisco",
                "vibeTag": "🍷 Sophisticated",
                "activeUsers": ["user9", "user10", "user11"],
                "pendingRequests": [],
                "createdAt": Calendar.current.date(byAdding: .hour, value: -3, to: baseDate) ?? baseDate,
                "title": "Wine Tasting Evening 🍷",
                "ticketPrice": 35.0,
                "coverPhotoURL": "",
                "maxGuestCount": 20,
                "visibility": "public",
                "approvalType": "automatic",
                "ageRestriction": 25,
                "maxMaleRatio": 0.5,
                "legalDisclaimerAccepted": true,
                "guestRequests": [],
                "earnings": 0.0,
                "bondfyrFee": 0.0,
                "isDemoData": true
            ],
            
            // Beach bonfire party
            [
                "id": "demo-party-4",
                "userId": "demo-host-4",
                "hostHandle": "mike_beach",
                "coordinate": sfCoordinate,
                "radius": 1000.0,
                "startTime": Calendar.current.date(byAdding: .day, value: 3, to: baseDate) ?? baseDate,
                "endTime": Calendar.current.date(byAdding: .day, value: 3, to: Calendar.current.date(byAdding: .hour, value: 8, to: baseDate) ?? baseDate) ?? baseDate,
                "city": "San Francisco",
                "locationName": "Ocean Beach",
                "description": "Beach bonfire with s'mores, acoustic guitars, and sunset views. Bring a jacket and good vibes!",
                "address": "Ocean Beach, San Francisco, CA",
                "googleMapsLink": "https://maps.google.com/?q=Ocean+Beach+San+Francisco",
                "vibeTag": "🏖️ Outdoorsy",
                "activeUsers": ["user12", "user13"],
                "pendingRequests": ["user14", "user15", "user16"],
                "createdAt": Calendar.current.date(byAdding: .minute, value: -30, to: baseDate) ?? baseDate,
                "title": "Beach Bonfire & Sunset 🏖️",
                "ticketPrice": 10.0,
                "coverPhotoURL": "",
                "maxGuestCount": 30,
                "visibility": "public",
                "approvalType": "manual",
                "ageRestriction": 18,
                "maxMaleRatio": 0.6,
                "legalDisclaimerAccepted": true,
                "guestRequests": [],
                "earnings": 0.0,
                "bondfyrFee": 0.0,
                "isDemoData": true
            ],
            
            // Karaoke night
            [
                "id": "demo-party-5",
                "userId": "demo-host-5",
                "hostHandle": "jenny_karaoke",
                "coordinate": sfCoordinate,
                "radius": 250.0,
                "startTime": Calendar.current.date(byAdding: .hour, value: 1, to: baseDate) ?? baseDate,
                "endTime": Calendar.current.date(byAdding: .hour, value: 6, to: baseDate) ?? baseDate,
                "city": "San Francisco",
                "locationName": "Stars Karaoke Lounge",
                "description": "Let your inner rockstar shine! Private karaoke room with drinks, snacks, and great company. All singing levels welcome!",
                "address": "321 Music Ave, San Francisco, CA",
                "googleMapsLink": "https://maps.google.com/?q=321+Music+Ave+San+Francisco",
                "vibeTag": "🎤 Fun",
                "activeUsers": ["user17", "user18", "user19", "user20"],
                "pendingRequests": ["user21"],
                "createdAt": Calendar.current.date(byAdding: .minute, value: -45, to: baseDate) ?? baseDate,
                "title": "Karaoke Night Fever 🎤",
                "ticketPrice": 18.0,
                "coverPhotoURL": "",
                "maxGuestCount": 16,
                "visibility": "public",
                "approvalType": "automatic",
                "ageRestriction": 21,
                "maxMaleRatio": 0.55,
                "legalDisclaimerAccepted": true,
                "guestRequests": [],
                "earnings": 0.0,
                "bondfyrFee": 0.0,
                "isDemoData": true
            ]
        ]
    }
    
    // MARK: - Demo Payment Simulation
    
    func simulatePayment(completion: @escaping (Bool) -> Void) {
        // Simulate payment processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            completion(true) // Always succeed in demo mode
        }
    }
    
    // MARK: - Demo Guest Simulation
    
    func simulateGuestInteractions(for partyId: String) {
        guard isDemoMode else { return }
        
        // Simulate new guest requests periodically for demo
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            self.simulateNewGuestRequest(for: partyId)
        }
        
        // Simulate party updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
            self.simulatePartyUpdate(for: partyId)
        }
    }
    
    private func simulatePartyUpdate(for partyId: String) {
        let updates = [
            "New guest joined your party! 🎉",
            "Someone liked your party! ❤️", 
            "Party reminder: Starting in 1 hour! ⏰",
            "Weather looks perfect for your event! ☀️"
        ]
        
        let randomUpdate = updates.randomElement() ?? "Party update!"
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("DemoPartyUpdate"),
                object: nil,
                userInfo: [
                    "partyId": partyId,
                    "message": randomUpdate
                ]
            )
        }
    }
    
    private func simulateNewGuestRequest(for partyId: String) {
        let guestNames = ["Jake Miller", "Sarah Wilson", "Chris Davis", "Maya Patel", "Jordan Lee"]
        let randomGuest = guestNames.randomElement() ?? "Random Guest"
        
        // Simulate notification
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("DemoGuestRequest"),
                object: nil,
                userInfo: [
                    "partyId": partyId,
                    "guestName": randomGuest,
                    "message": "\(randomGuest) wants to join your party!"
                ]
            )
        }
    }
    
    // MARK: - Demo Mode Cleanup
    
    func clearDemoData() async {
        guard !isDemoMode else { return } // Don't clear if still in demo mode
        
        // Clear demo parties
        let demoPartyIds = ["demo-party-1", "demo-party-2", "demo-party-3", "demo-party-host", "demo-party-4"]
        
        for partyId in demoPartyIds {
            do {
                try await db.collection("afterparties").document(partyId).delete()
                print("🗑️ Deleted demo party: \(partyId)")
            } catch {
                print("❌ Error deleting demo party: \(error)")
            }
        }
        
        // Clear demo mode flag
        UserDefaults.standard.removeObject(forKey: "isDemoMode")
    }
}
