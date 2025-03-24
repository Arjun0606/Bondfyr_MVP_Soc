//
//  TicketModel.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import Foundation

struct TicketModel: Codable {
    let event: String
    let tier: String
    let count: Int
    let genders: [String]
    let prCode: String
    let timestamp: String
    let ticketId: String
}
