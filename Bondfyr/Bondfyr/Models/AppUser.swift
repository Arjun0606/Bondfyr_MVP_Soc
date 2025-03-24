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
}
