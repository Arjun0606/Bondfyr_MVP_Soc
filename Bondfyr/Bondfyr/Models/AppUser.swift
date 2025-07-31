//
//  AppUser.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import Foundation

struct AppUser: Codable {
    let uid: String
    let name: String
    let email: String
    let dob: Date
    let phoneNumber: String
    let role: UserRole
    let username: String?
    let gender: String? // Gender: "male", "female", "custom"
    let bio: String? // User bio/description
    let instagramHandle: String?
    let snapchatHandle: String?
    let avatarURL: String?
    let googleID: String?
    let city: String?
    
    // --- Simple Stats & Verification System ---
    
    // Core Activity Stats (Actually Trackable!)
    let partiesHosted: Int?           // Parties that had guests and completed successfully
    let partiesAttended: Int?         // Parties where user actually checked in during event
    let totalPartyHours: Int?         // Total hours spent at parties (trackable via check-ins)
    let accountAgeDays: Int?          // Days since account creation (always accurate)
    
    // New Robust Reputation System Properties
    let hostedPartiesCount: Int?      // Host credit only after 20% guest rating threshold
    let attendedPartiesCount: Int?    // Incremented immediately upon successful check-in
    let lastRatedPartyId: String?     // Prevent duplicate ratings from same user
    
    // Simple Verification (No Ratings Required)
    let isHostVerified: Bool?         // Verified after 3 successful parties
    let isGuestVerified: Bool?        // Verified after 5 attended parties
    
    // Account Lifecycle
    let accountCreated: Date?         // When they joined Bondfyr
    let lastActiveParty: Date?        // Most recent party participation
    
    // Social Connections (Actually Connected)
    let instagramConnected: Bool?     // Has connected Instagram
    let snapchatConnected: Bool?      // Has connected Snapchat
    
    enum UserRole: String, Codable {
        case user
        case vendor
        case admin
    }
    
    init(uid: String, name: String, email: String, dob: Date, phoneNumber: String, role: UserRole = .user, username: String? = nil, gender: String? = nil, bio: String? = nil, instagramHandle: String? = nil, snapchatHandle: String? = nil, avatarURL: String? = nil, googleID: String? = nil, city: String? = nil, partiesHosted: Int? = 0, partiesAttended: Int? = 0, totalPartyHours: Int? = 0, accountAgeDays: Int? = 0, hostedPartiesCount: Int? = 0, attendedPartiesCount: Int? = 0, lastRatedPartyId: String? = nil, isHostVerified: Bool? = false, isGuestVerified: Bool? = false, accountCreated: Date? = Date(), lastActiveParty: Date? = nil, instagramConnected: Bool? = false, snapchatConnected: Bool? = false) {
        self.uid = uid
        self.name = name
        self.email = email
        self.dob = dob
        self.phoneNumber = phoneNumber
        self.role = role
        self.username = username
        self.gender = gender
        self.bio = bio
        self.instagramHandle = instagramHandle
        self.snapchatHandle = snapchatHandle
        self.avatarURL = avatarURL
        self.googleID = googleID
        self.city = city
        
        // Simple Stats
        self.partiesHosted = partiesHosted
        self.partiesAttended = partiesAttended
        self.totalPartyHours = totalPartyHours
        self.accountAgeDays = accountAgeDays
        
        // New Reputation System
        self.hostedPartiesCount = hostedPartiesCount
        self.attendedPartiesCount = attendedPartiesCount
        self.lastRatedPartyId = lastRatedPartyId
        
        self.isHostVerified = isHostVerified
        self.isGuestVerified = isGuestVerified
        self.accountCreated = accountCreated
        self.lastActiveParty = lastActiveParty
        self.instagramConnected = instagramConnected
        self.snapchatConnected = snapchatConnected
    }
    
    // MARK: - Computed Properties for Display
    
    var hostVerificationProgress: Double {
        let hosted = partiesHosted ?? 0
        return min(Double(hosted) / 3.0, 1.0) // 3 parties needed
    }
    
    var guestVerificationProgress: Double {
        let attended = partiesAttended ?? 0
        return min(Double(attended) / 5.0, 1.0) // 5 parties needed
    }
    
    var nextHostMilestone: Int? {
        let hosted = partiesHosted ?? 0
        let milestones = [1, 3, 5, 10, 25, 50]
        return milestones.first { $0 > hosted }
    }
    
    var nextGuestMilestone: Int? {
        let attended = partiesAttended ?? 0
        let milestones = [1, 5, 10, 25, 50]
        return milestones.first { $0 > attended }
    }
    
    var isActiveUser: Bool {
        guard let lastActive = lastActiveParty else { return false }
        return Date().timeIntervalSince(lastActive) < (30 * 24 * 60 * 60) // Active within 30 days
    }
    
    // Realistic engagement metrics
    var averagePartyDuration: Double {
        guard let hosted = partiesHosted, let attended = partiesAttended,
              let totalHours = totalPartyHours,
              (hosted + attended) > 0 else { return 0 }
        return Double(totalHours) / Double(hosted + attended)
    }
    
    var accountAgeDisplayText: String {
        guard let days = accountAgeDays else { return "New" }
        if days < 7 {
            return "New Member"
        } else if days < 30 {
            return "\(days) days old"
        } else if days < 365 {
            let months = days / 30
            return "\(months) month\(months == 1 ? "" : "s") old"
        } else {
            let years = days / 365
            return "\(years) year\(years == 1 ? "" : "s") old"
        }
    }
}
