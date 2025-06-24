//
//  PartyLike.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import Foundation
import FirebaseFirestore

struct PartyLike: Codable, Identifiable {
    let id: String
    let eventId: String
    let likerId: String
    let likedId: String
    let timestamp: Timestamp
    
    init(eventId: String, likerId: String, likedId: String, timestamp: Timestamp) {
        self.id = UUID().uuidString
        self.eventId = eventId
        self.likerId = likerId
        self.likedId = likedId
        self.timestamp = timestamp
    }
} 