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
    
    // --- Verification & Reputation System ---
    
    // Verification Status
    let isHostVerified: Bool?
    let isGuestVerified: Bool?
    
    // Progress Tracking
    let hostedPartiesCount: Int?
    let attendedPartiesCount: Int?
    
    // User Ratings (average)
    let hostRating: Double?
    let guestRating: Double?
    
    // Rating Counts
    let hostRatingsCount: Int?
    let guestRatingsCount: Int?
    
    // Social Connections
    let totalLikesReceived: Int?
    
    // Host verification tracking
    let successfulPartiesCount: Int?
    
    enum UserRole: String, Codable {
        case user
        case vendor
        case admin
    }
    
    init(uid: String, name: String, email: String, dob: Date, phoneNumber: String, role: UserRole = .user, username: String? = nil, gender: String? = nil, bio: String? = nil, instagramHandle: String? = nil, snapchatHandle: String? = nil, avatarURL: String? = nil, googleID: String? = nil, city: String? = nil, isHostVerified: Bool? = false, isGuestVerified: Bool? = false, hostedPartiesCount: Int? = 0, attendedPartiesCount: Int? = 0, hostRating: Double? = 0.0, guestRating: Double? = 0.0, hostRatingsCount: Int? = 0, guestRatingsCount: Int? = 0, totalLikesReceived: Int? = 0, successfulPartiesCount: Int? = 0) {
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
        
        // --- Verification & Reputation ---
        self.isHostVerified = isHostVerified
        self.isGuestVerified = isGuestVerified
        self.hostedPartiesCount = hostedPartiesCount
        self.attendedPartiesCount = attendedPartiesCount
        self.hostRating = hostRating
        self.guestRating = guestRating
        self.hostRatingsCount = hostRatingsCount
        self.guestRatingsCount = guestRatingsCount
        self.totalLikesReceived = totalLikesReceived
        self.successfulPartiesCount = successfulPartiesCount
    }
}
