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
        ZStack(alignment: .bottomLeading) {
            // Background Image
            Image(event.venueLogoImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .cornerRadius(12)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.8)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .cornerRadius(12)
                )
                .clipped()
            
            // Event Information
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                        .font(.caption)
                    
                    Text(event.date)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Image(systemName: "mappin.circle")
                        .foregroundColor(.gray)
                        .font(.caption)
                    
                    Text(event.venue)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(15)
        }
        .frame(height: 200)
        .background(Color.black)
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}
