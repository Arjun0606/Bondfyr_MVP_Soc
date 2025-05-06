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
    let instagramHandle: String?
    let snapchatHandle: String?
    let avatarURL: String?
    let googleID: String?
    let city: String?
    
    enum UserRole: String, Codable {
        case user
        case vendor
        case admin
    }
    
    init(uid: String, name: String, email: String, dob: Date, phoneNumber: String, role: UserRole = .user, instagramHandle: String? = nil, snapchatHandle: String? = nil, avatarURL: String? = nil, googleID: String? = nil, city: String? = nil) {
        self.uid = uid
        self.name = name
        self.email = email
        self.dob = dob
        self.phoneNumber = phoneNumber
        self.role = role
        self.instagramHandle = instagramHandle
        self.snapchatHandle = snapchatHandle
        self.avatarURL = avatarURL
        self.googleID = googleID
        self.city = city
    }
}
