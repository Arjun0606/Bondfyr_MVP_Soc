//
//  TicketStorage.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import Foundation

struct TicketStorage {
    private static let key = "saved_tickets"
    
    static func save(_ ticket: TicketModel) {
        var tickets = load()
        tickets.append(ticket)
        saveAll(tickets)
    }
    
    static func saveAll(_ tickets: [TicketModel]) {
        if let encoded = try? JSONEncoder().encode(tickets) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    static func load() -> [TicketModel] {
        if let data = UserDefaults.standard.data(forKey: key) {
            if let decoded = try? JSONDecoder().decode([TicketModel].self, from: data) {
                return decoded
            }
        }
        return []
    }
    
    static func delete(ticketId: String) {
        var tickets = load()
        tickets.removeAll { $0.ticketId == ticketId }
        saveAll(tickets)
    }
}
