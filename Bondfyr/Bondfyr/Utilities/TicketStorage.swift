//
//  TicketStorage.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import Foundation

struct TicketStorage {
    static let key = "saved_tickets"

    static func save(_ ticket: TicketModel) {
        var existing = load()
        existing.append(ticket)

        if let data = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> [TicketModel] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let tickets = try? JSONDecoder().decode([TicketModel].self, from: data) else {
            return []
        }
        return tickets
    }
}
