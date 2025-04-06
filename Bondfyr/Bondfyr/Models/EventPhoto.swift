//
//  EventPhoto.swift
//  Bondfyr
//
//  Created by Arjun Varma on 31/03/25.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestore

struct EventPhoto: Identifiable, Codable {
    @DocumentID var id: String?
    var eventId: String
    var uploaderId: String
    var imageUrl: String
    var timestamp: Date
    var likes: Int = 0
    var isContestEntry: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventId
        case uploaderId
        case imageUrl
        case timestamp
        case likes
        case isContestEntry
    }
}
