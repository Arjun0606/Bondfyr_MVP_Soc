//
//  AppStoreDemoManager.swift
//  Bondfyr
//
//  Created for App Store Review
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

class AppStoreDemoManager: ObservableObject {
    static let shared = AppStoreDemoManager()
    
    // Demo account credentials for App Store reviewers
    static let demoEmail = "appstore.reviewer@bondfyr.demo"
    static let demoPassword = "AppStore2025!"
    static let demoUserId = "demo-appstore-reviewer-2025"
    
    @Published var isDemoAccount = false
    @Published var hostMode = true // true = host experience, false = guest experience
    
    private let db = Firestore.firestore()
    
    private init() {
        checkIfDemoAccount()
    }
    
    // MARK: - Demo Account Detection
    
    func checkIfDemoAccount() {
        guard let currentUser = Auth.auth().currentUser else {
            isDemoAccount = false
            return
        }
        
        isDemoAccount = currentUser.email == AppStoreDemoManager.demoEmail
        print("🎭 Demo account status: \(isDemoAccount)")
        
        // If this is the demo account, create demo content
        if isDemoAccount {
            Task {
                await createDemoContent()
            }
        }
    }
    
    // MARK: - Demo Account Creation
    
    func createDemoAccountIfNeeded() async {
        do {
            // Try to sign in first to check if account exists
            let result = try await Auth.auth().signIn(withEmail: AppStoreDemoManager.demoEmail, password: AppStoreDemoManager.demoPassword)
            print("✅ Demo account already exists: \(result.user.uid)")
            
            // Update the profile to ensure it's complete
            await updateDemoUserProfile(userId: result.user.uid)
            
        } catch {
            // Account doesn't exist, create it
            print("🔧 Creating new demo account...")
            await createNewDemoAccount()
        }
    }
    
    private func createNewDemoAccount() async {
        do {
            let result = try await Auth.auth().createUser(withEmail: AppStoreDemoManager.demoEmail, password: AppStoreDemoManager.demoPassword)
            print("✅ Created demo account: \(result.user.uid)")
            
            // Create comprehensive user profile
            await updateDemoUserProfile(userId: result.user.uid)
            
            // Create demo parties and interactions
            await createDemoContent()
            
        } catch {
            print("❌ Error creating demo account: \(error)")
        }
    }
    
    private func updateDemoUserProfile(userId: String) async {
        let userData: [String: Any] = [
            "uid": userId,
            "email": AppStoreDemoManager.demoEmail,
            "name": "App Store Reviewer",
            "username": "AppStoreReviewer",
            "photoURL": "",
            "role": "demo_reviewer",
            "lastLogin": Timestamp(),
            "isDemoAccount": true,
            "isAppStoreReviewer": true,
            "city": "Austin",
            "currentCity": "Austin",
            "location": GeoPoint(latitude: 30.2672, longitude: -97.7431),
            "dob": Date(timeIntervalSince1970: 631152000), // Jan 1, 1990
            "phoneNumber": "+1-800-APP-STORE",
            "gender": "non-binary",
            "bio": "Demo account for App Store review process - can test all features",
            "instagramHandle": "",
            "snapchatHandle": "",
            "avatarURL": "",
            "googleID": userId,
            "isHostVerified": true,
            "isGuestVerified": true,
            "hostedPartiesCount": 15,
            "attendedPartiesCount": 25,
            "hostRating": 4.9,
            "guestRating": 4.8,
            "hostRatingsCount": 30,
            "guestRatingsCount": 20,
            "totalEarnings": 0.0, // Demo account - no real money
            "totalSpent": 0.0,
            "totalLikesReceived": 50,
            "createdAt": Timestamp(date: Date()),
            "lastActiveAt": Timestamp(date: Date())
        ]
        
        do {
            try await db.collection("users").document(userId).setData(userData, merge: true)
            print("✅ Demo user profile created/updated")
        } catch {
            print("❌ Error updating demo user profile: \(error)")
        }
    }
    
    // MARK: - Demo Content Creation
    
    private func createDemoContent() async {
        // Create demo parties using the enhanced function
        await createDemoParties()
    }
    
    private func generateDemoParties() -> [[String: Any]] {
        let baseDate = Date()
        let atxCoordinate = GeoPoint(latitude: 30.2672, longitude: -97.7431)
        let demoAccountUserId = Auth.auth().currentUser?.uid ?? "demo-appstore-reviewer-2025"
        
        return [
            // Tonight's party - Host view
            [
                "id": "demo-host-party-1",
                "userId": demoAccountUserId, // This party is hosted BY the demo account
                "hostHandle": "AppStoreReviewer",
                "coordinate": atxCoordinate,
                "radius": 500.0,
                "startTime": Calendar.current.date(byAdding: .hour, value: 2, to: baseDate) ?? baseDate,
                "endTime": Calendar.current.date(byAdding: .hour, value: 8, to: baseDate) ?? baseDate,
                "city": "Austin",
                "locationName": "East Side Loft",
                "description": "Austin demo party! Manage guests and test all host controls.",
                "address": "123 Demo St, Austin, TX",
                "googleMapsLink": "https://maps.google.com/?q=123+Demo+St+Austin",
                "vibeTag": "🎉 Energetic",
                "activeUsers": ["guest1", "guest2", "guest3"],
                "pendingRequests": ["guest4", "guest5"],
                "createdAt": Calendar.current.date(byAdding: .hour, value: -1, to: baseDate) ?? baseDate,
                "title": "Austin End Sem House Party 🎉",
                "ticketPrice": 5.0,
                "coverPhotoURL": "https://raw.githubusercontent.com/Arjun0606/assets/main/demo_austin.jpg",
                "maxGuestCount": 20,
                "visibility": "public",
                "approvalType": "manual",
                "ageRestriction": "21+",
                "maxMaleRatio": 0.6,
                "legalDisclaimerAccepted": true,
                "completionStatus": "ongoing",
                "guestRequests": [
                    [
                        "userId": "guest4",
                        "userName": "John Demo",
                        "status": "pending",
                        "requestedAt": Timestamp(date: Date()),
                        "photoURL": ""
                    ],
                    [
                        "userId": "guest5",
                        "userName": "Sarah Test",
                        "status": "pending",
                        "requestedAt": Timestamp(date: Date()),
                        "photoURL": ""
                    ]
                ],
                "earnings": 0.0,
                "bondfyrFee": 0.0,
                "isDemoData": true
            ],
            
            // Party to join - Guest view
            [
                "id": "demo-guest-party-1",
                "userId": "other-host-1",
                "hostHandle": "CoolHost123",
                "coordinate": atxCoordinate,
                "radius": 300.0,
                "startTime": Calendar.current.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate,
                "endTime": Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.date(byAdding: .hour, value: 5, to: baseDate) ?? baseDate) ?? baseDate,
                "city": "Austin",
                "locationName": "South Congress House",
                "description": "Guest experience — request to join and view details.",
                "address": "456 Guest Ave, Austin, TX",
                "googleMapsLink": "https://maps.google.com/?q=456+Guest+Ave+Austin",
                "vibeTag": "🍸 Chill",
                "activeUsers": ["user1", "user2"],
                "pendingRequests": [],
                "createdAt": Calendar.current.date(byAdding: .hour, value: -2, to: baseDate) ?? baseDate,
                "title": "Austin End Sem House Party 🍸",
                "ticketPrice": 5.0,
                "coverPhotoURL": "https://raw.githubusercontent.com/Arjun0606/assets/main/demo_austin.jpg",
                "maxGuestCount": 15,
                "visibility": "public",
                "approvalType": "automatic",
                "ageRestriction": "18+",
                "maxMaleRatio": 0.5,
                "legalDisclaimerAccepted": true,
                "completionStatus": "ongoing",
                "guestRequests": [],
                "earnings": 0.0,
                "bondfyrFee": 0.0,
                "isDemoData": true
            ],
            
            // Weekend party
            [
                "id": "demo-party-weekend",
                "userId": "other-host-2",
                "hostHandle": "WeekendVibes",
                "coordinate": atxCoordinate,
                "radius": 800.0,
                "startTime": Calendar.current.date(byAdding: .day, value: 2, to: baseDate) ?? baseDate,
                "endTime": Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.date(byAdding: .hour, value: 6, to: baseDate) ?? baseDate) ?? baseDate,
                "city": "Austin",
                "locationName": "Riverside Backyard",
                "description": "Weekend party for testing different party types and interactions.",
                "address": "789 Riverside Dr, Austin, TX",
                "googleMapsLink": "https://maps.google.com/?q=789+Riverside+Dr+Austin",
                "vibeTag": "🌟 Exclusive",
                "activeUsers": ["user3", "user4", "user5"],
                "pendingRequests": [],
                "createdAt": Calendar.current.date(byAdding: .minute, value: -45, to: baseDate) ?? baseDate,
                "title": "Weekend Austin Party 🌟",
                "ticketPrice": 5.0,
                "coverPhotoURL": "https://raw.githubusercontent.com/Arjun0606/assets/main/demo_austin.jpg",
                "maxGuestCount": 30,
                "visibility": "public",
                "approvalType": "manual",
                "ageRestriction": "21+",
                "maxMaleRatio": 0.55,
                "legalDisclaimerAccepted": true,
                "completionStatus": "ongoing",
                "guestRequests": [],
                "earnings": 0.0,
                "bondfyrFee": 0.0,
                "isDemoData": true
            ]
        ]
    }
    
    // MARK: - Demo Features
    
    func clearExistingDemoParties() async {
        print("🧹 Clearing existing demo parties and user parties...")
        
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No authenticated user for clearing parties")
            return
        }
        
        do {
            print("🔧 Current user email: \(currentUser.email ?? "no email")")
            print("🔧 Current user UID: \(currentUser.uid)")
            
            // Clear demo parties
            let demoSnapshot = try await db.collection("afterparties").whereField("isDemoData", isEqualTo: true).getDocuments()
            print("🔧 Found \(demoSnapshot.documents.count) demo parties to delete")
            
            for document in demoSnapshot.documents {
                do {
                    try await document.reference.delete()
                    print("🗑️ Successfully deleted demo party: \(document.documentID)")
                } catch {
                    print("❌ Failed to delete demo party \(document.documentID): \(error)")
                }
            }
            
            // Clear ANY parties created by demo account (to fix "Active Afterparty Exists" error)
            let userSnapshot = try await db.collection("afterparties").whereField("userId", isEqualTo: currentUser.uid).getDocuments()
            print("🔧 Found \(userSnapshot.documents.count) user parties to delete")
            
            for document in userSnapshot.documents {
                do {
                    try await document.reference.delete()
                    print("🗑️ Successfully deleted existing party for demo user: \(document.documentID)")
                } catch {
                    print("❌ Failed to delete user party \(document.documentID): \(error)")
                }
            }
            
            print("✅ Cleared \(demoSnapshot.documents.count) demo parties and \(userSnapshot.documents.count) user parties")
        } catch {
            print("❌ Error clearing demo parties: \(error)")
            print("❌ Clear error details: \(error.localizedDescription)")
        }
    }
    
    func createDemoParties() async {
        print("🔧 Creating demo parties for App Store review...")
        
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No authenticated user - cannot create demo parties")
            return
        }
        
        print("🔧 Current user: \(currentUser.uid)")
        
        do {
            // Clear existing demo parties first
            await clearExistingDemoParties()
            
            // Create 6 demo parties with current timestamp for immediate visibility
            let demoParties = generateDemoParties()
            
            for party in demoParties {
                let partyData = party
                print("🔧 Creating party: \(partyData["title"] as? String ?? "Unknown") for user: \(partyData["userId"] as? String ?? "Unknown")")
                print("🔧 Party data isDemoData: \(partyData["isDemoData"] as? Bool ?? false)")
                print("🔧 Current user email: \(currentUser.email ?? "no email")")
                
                do {
                    try await Firestore.firestore().collection("afterparties").document(party["id"] as! String).setData(party)
                    print("✅ Successfully created demo party: \(party["title"] as! String)")
                } catch {
                    print("❌ Failed to create party \(party["title"] as! String): \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                }
                
                // Add a small delay to avoid overwhelming Firestore
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            }
            
            print("🎉 All demo parties created successfully!")
            
            // Force party data refresh in the app
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshPartyData"), object: nil)
            }
            
        } catch {
            print("❌ Error creating demo party: \(error)")
        }
    }
    
    func shouldBypassPayments() -> Bool {
        return isDemoAccount
    }
    
    func shouldShowUnlimitedHosting() -> Bool {
        return isDemoAccount
    }
    
    func shouldShowAllParties() -> Bool {
        // Demo account should see ALL parties (including their own hosted ones)
        return isDemoAccount
    }
    
    func shouldSkipVerification() -> Bool {
        // Demo account should skip any verification steps
        return isDemoAccount
    }
    
    func toggleHostGuestMode() {
        hostMode.toggle()
        print("🎭 Demo mode switched to: \(hostMode ? "HOST" : "GUEST") experience")
    }
    
    // MARK: - Cleanup
    
    func cleanupDemoData() async {
        // Remove demo parties when needed
        do {
            let snapshot = try await db.collection("afterparties").whereField("isDemoData", isEqualTo: true).getDocuments()
            for document in snapshot.documents {
                try await document.reference.delete()
            }
            print("🗑️ Cleaned up demo data")
        } catch {
            print("❌ Error cleaning demo data: \(error)")
        }
    }
}
