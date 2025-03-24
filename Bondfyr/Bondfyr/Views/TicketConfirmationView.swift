//
//  TicketConfirmationView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct TicketConfirmationView: View {
    let ticket: TicketModel

    var body: some View {
        VStack(spacing: 16) {
            Text("✅ Ticket Confirmed")
                .foregroundColor(.green)
                .font(.headline)

            Image(uiImage: QRGenerator.generate(from: ticket))
                .interpolation(.none)
                .resizable()
                .frame(width: 200, height: 200)
                .background(Color.white)
                .cornerRadius(10)

            VStack(spacing: 6) {
                Text("\(ticket.event) — \(ticket.tier)")
                    .foregroundColor(.white)
                    .font(.title3)

                Text("Entry on: \(formattedDate(ticket.timestamp))")
                    .foregroundColor(.gray)

                Text("👥 \(ticket.count) Attendees — \(genderSummary(ticket.genders))")
                    .foregroundColor(.pink)
            }
        }
        .padding()
        .background(Color.black.opacity(0.9))
        .cornerRadius(15)
    }

    func formattedDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: isoString) {
            let out = DateFormatter()
            out.dateStyle = .medium
            out.timeStyle = .short
            return out.string(from: date)
        }
        return isoString
    }

    func genderSummary(_ genders: [String]) -> String {
        let counts = Dictionary(grouping: genders, by: { $0 }).mapValues { $0.count }
        return counts.map { "\($0.value)x \($0.key)" }.joined(separator: ", ")
    }
}
