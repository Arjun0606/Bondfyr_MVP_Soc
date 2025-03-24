//
//  EventCardView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI

struct EventCardView: View {
    let event: Event

    var body: some View {
        HStack(spacing: 16) {
            Image(event.image)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(event.location)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(event.date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding()
        .background(Color.black)
        .cornerRadius(16)
    }
}
