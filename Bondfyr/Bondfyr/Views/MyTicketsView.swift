//
//  MyTicketsView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct MyTicketsView: View {
    @State private var tickets: [TicketModel] = []

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    if tickets.isEmpty {
                        Text("No tickets yet.")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(tickets, id: \.ticketId) { ticket in
                            TicketConfirmationView(ticket: ticket)
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear {
            tickets = TicketStorage.load()
        }
    }
}
