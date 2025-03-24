//
//  MyTicketsView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct MyTicketsView: View {
    @State private var dummyTicket = "Vault-VIP-Female-PR123"
    @State private var eventDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())!

    var body: some View {
        VStack(spacing: 20) {
            Text("Your Upcoming Ticket")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Image(uiImage: QRGenerator.generate(from: dummyTicket))
                .interpolation(.none)
                .resizable()
                .frame(width: 200, height: 200)
                .background(Color.white)
                .cornerRadius(10)

            Text("Vault — VIP")
                .foregroundColor(.white)
                .font(.headline)

            Text("Entry on: \(formattedDate(eventDate))")
                .foregroundColor(.gray)

            Text("⏳ \(timeRemaining(to: eventDate)) left")
                .foregroundColor(.pink)
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }

    func timeRemaining(to date: Date) -> String {
        let diff = Calendar.current.dateComponents([.day, .hour, .minute], from: Date(), to: date)
        return "\(diff.day ?? 0)d \(diff.hour ?? 0)h \(diff.minute ?? 0)m"
    }
}
