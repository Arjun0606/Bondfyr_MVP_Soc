//
//  MyTicketsView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct MyTicketsView: View {
    @State private var dummyTicket = TicketModel(
        event: "Vault",
        tier: "VIP",
        count: 1,
        genders: ["Male"],
        prCode: "PR123",
        timestamp: ISO8601DateFormatter().string(from: Date()),
        ticketId: UUID().uuidString
    )

    @State private var eventDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())!

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text("Your Upcoming Ticket")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)

                    Image(uiImage: QRGenerator.generate(from: dummyTicket))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 200, height: 200)
                        .background(Color.white)
                        .cornerRadius(10)

                    Text("\(dummyTicket.event) — \(dummyTicket.tier)")
                        .foregroundColor(.white)
                        .font(.headline)

                    Text("Entry on: \(formattedDate(eventDate))")
                        .foregroundColor(.gray)

                    HStack {
                        Image(systemName: "hourglass")
                        Text("2d 23h 59m left")
                    }
                    .foregroundColor(.pink)
                }
                .padding()
            }
        }
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
