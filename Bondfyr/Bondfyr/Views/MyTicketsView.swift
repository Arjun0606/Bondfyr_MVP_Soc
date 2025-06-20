//
//  MyTicketsView.swift
//  Bondfyr
//
//  Created by Arjun Varma on 24/03/25.
//

import SwiftUI
import CoreLocation

struct MyTicketsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @State private var upcomingParties: [Afterparty] = []
    @State private var pastParties: [Afterparty] = []
    @State private var isLoading = false
    @State private var selectedParty: Afterparty? = nil
    @State private var showingTicketDetail = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        LoadingSection()
                    } else if upcomingParties.isEmpty && pastParties.isEmpty {
                        EmptyTicketsSection()
                    } else {
                        VStack(spacing: 24) {
                            if !upcomingParties.isEmpty {
                                UpcomingPartiesSection(
                                    parties: upcomingParties,
                                    onPartyTap: { party in
                                        selectedParty = party
                                        showingTicketDetail = true
                                    }
                                )
                            }
                            
                            if !pastParties.isEmpty {
                                PastPartiesSection(parties: pastParties)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("My Tickets")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingTicketDetail) {
            if let party = selectedParty {
                TicketDetailView(party: party)
            }
        }
        .task {
            await loadUserTickets()
        }
    }
    
    private func loadUserTickets() async {
        isLoading = true
        defer { isLoading = false }
        
        // Load sample data for demo
        let sampleTickets = createSampleUserTickets()
        
        await MainActor.run {
            let now = Date()
            upcomingParties = sampleTickets.filter { $0.startTime > now }
            pastParties = sampleTickets.filter { $0.startTime <= now }
        }
    }
    
    private func createSampleUserTickets() -> [Afterparty] {
        let now = Date()
        let calendar = Calendar.current
        
        return [
            // Upcoming party tonight
            Afterparty(
                id: "my-ticket-1",
                userId: "host-user-1",
                hostHandle: "party_alex",
                coordinate: CLLocationCoordinate2D(latitude: 18.4955, longitude: 73.9040),
                radius: 1000,
                startTime: calendar.date(byAdding: .hour, value: 4, to: now) ?? now,
                endTime: calendar.date(byAdding: .hour, value: 8, to: now) ?? now,
                city: "Pune",
                locationName: "Rooftop Terrace",
                description: "Epic rooftop party with DJ and city views!",
                address: "123 MG Road, Pune",
                googleMapsLink: "https://maps.google.com/?q=123+MG+Road+Pune",
                vibeTag: "Rooftop, Dancing, Music",
                activeUsers: Array(1...15).map { "guest-\($0)" },
                pendingRequests: [],
                createdAt: calendar.date(byAdding: .hour, value: -2, to: now) ?? now,
                title: "🌆 Saturday Rooftop Bash",
                ticketPrice: 25.0,
                coverPhotoURL: nil,
                maxGuestCount: 50,
                visibility: .publicFeed,
                approvalType: .automatic,
                ageRestriction: 21,
                maxMaleRatio: 0.6,
                legalDisclaimerAccepted: true,
                guestRequests: []
            ),
            
            // Upcoming party tomorrow
            Afterparty(
                id: "my-ticket-2",
                userId: "host-user-2",
                hostHandle: "pool_party_pro",
                coordinate: CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567),
                radius: 1000,
                startTime: calendar.date(byAdding: .day, value: 1, to: now) ?? now,
                endTime: calendar.date(byAdding: .day, value: 1, to: calendar.date(byAdding: .hour, value: 6, to: now) ?? now) ?? now,
                city: "Pune",
                locationName: "Private Pool Villa",
                description: "Pool party with BBQ and games!",
                address: "456 Koregaon Park, Pune",
                googleMapsLink: "https://maps.google.com/?q=456+Koregaon+Park+Pune",
                vibeTag: "Pool, BBQ, Chill",
                activeUsers: Array(1...20).map { "guest-\($0)" },
                pendingRequests: [],
                createdAt: calendar.date(byAdding: .hour, value: -5, to: now) ?? now,
                title: "🏊‍♀️ Sunday Pool Party",
                ticketPrice: 30.0,
                coverPhotoURL: nil,
                maxGuestCount: 40,
                visibility: .publicFeed,
                approvalType: .automatic,
                ageRestriction: nil,
                maxMaleRatio: 0.5,
                legalDisclaimerAccepted: true,
                guestRequests: []
            ),
            
            // Past party
            Afterparty(
                id: "my-ticket-3",
                userId: "host-user-3",
                hostHandle: "house_party_king",
                coordinate: CLLocationCoordinate2D(latitude: 18.4648, longitude: 73.8772),
                radius: 1000,
                startTime: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                endTime: calendar.date(byAdding: .day, value: -2, to: calendar.date(byAdding: .hour, value: 4, to: now) ?? now) ?? now,
                city: "Pune",
                locationName: "Downtown Loft",
                description: "House party with beer pong and great music!",
                address: "789 FC Road, Pune",
                googleMapsLink: "https://maps.google.com/?q=789+FC+Road+Pune",
                vibeTag: "House Party, Games, Music",
                activeUsers: Array(1...25).map { "guest-\($0)" },
                pendingRequests: [],
                createdAt: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                title: "🏠 Friday Night House Party",
                ticketPrice: 20.0,
                coverPhotoURL: nil,
                maxGuestCount: 35,
                visibility: .publicFeed,
                approvalType: .automatic,
                ageRestriction: 18,
                maxMaleRatio: 0.7,
                legalDisclaimerAccepted: true,
                guestRequests: []
            )
        ]
    }
}

// MARK: - Loading Section
struct LoadingSection: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .pink))
                .scaleEffect(1.5)
            
            Text("Loading your tickets...")
                .foregroundColor(.gray)
        }
        .padding(.top, 100)
    }
}

// MARK: - Empty State
struct EmptyTicketsSection: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 80))
                .foregroundColor(.pink)
            
            VStack(spacing: 12) {
                Text("No tickets yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("When you buy tickets to parties, they'll show up here with party details, directions, and host info!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Discover Parties") {
                // TODO: Navigate to Party Feed
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
            .foregroundColor(.white)
            .cornerRadius(25)
        }
        .padding(.top, 60)
    }
}

// MARK: - Upcoming Parties Section
struct UpcomingPartiesSection: View {
    let parties: [Afterparty]
    let onPartyTap: (Afterparty) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming Parties")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(parties.count)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.pink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.pink.opacity(0.2))
                    .cornerRadius(12)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(parties) { party in
                    UpcomingPartyCard(party: party, onTap: { onPartyTap(party) })
                }
            }
        }
    }
}

// MARK: - Upcoming Party Card
struct UpcomingPartyCard: View {
    let party: Afterparty
    let onTap: () -> Void
    
    private var timeUntilParty: String {
        let now = Date()
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: party.startTime)
        
        if let days = components.day, days > 0 {
            return "in \(days) day\(days == 1 ? "" : "s")"
        } else if let hours = components.hour, hours > 0 {
            return "in \(hours) hour\(hours == 1 ? "" : "s")"
        } else if let minutes = components.minute, minutes > 0 {
            return "in \(minutes) min"
        } else {
            return "starting now!"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with time and price
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(party.title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("at \(party.locationName)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("$\(Int(party.ticketPrice))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        
                        Text("PAID")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                
                // Time info
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.pink)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDate(party.startTime))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Starts \(timeUntilParty)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    // Paid status indicator
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        Text("Confirmed")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                // Location and host
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    
                    Text(party.address)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("@\(party.hostHandle)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6).opacity(0.3))
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.pink.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d • h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Past Parties Section
struct PastPartiesSection: View {
    let parties: [Afterparty]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Past Parties")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            LazyVStack(spacing: 8) {
                ForEach(parties) { party in
                    PastPartyRow(party: party)
                }
            }
        }
    }
}

// MARK: - Past Party Row
struct PastPartyRow: View {
    let party: Afterparty
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(party.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(formatPastDate(party.startTime))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("$\(Int(party.ticketPrice))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6).opacity(0.05))
        .cornerRadius(12)
    }
    
    private func formatPastDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Ticket Detail View
struct TicketDetailView: View {
    let party: Afterparty
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Ticket Confirmation Section
                    TicketConfirmationSection(party: party)
                    
                    // Party Details
                    TicketPartyDetailsSection(party: party)
                    
                    // Action Buttons
                    ActionButtonsSection(party: party)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Your Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
        }
    }
}

// MARK: - Ticket Confirmation Section
struct TicketConfirmationSection: View {
    let party: Afterparty
    
    var body: some View {
        VStack(spacing: 16) {
            Text("You're Going!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Confirmation icon
            Circle()
                .fill(LinearGradient(gradient: Gradient(colors: [.green, .mint]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 120, height: 120)
                .overlay(
                    VStack {
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("PAID")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                )
            
            Text("Your spot is confirmed! The host will check you in when you arrive.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(20)
    }
}

// MARK: - Ticket Party Details Section
struct TicketPartyDetailsSection: View {
    let party: Afterparty
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Party Details")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
                         VStack(spacing: 12) {
                TicketDetailRow(
                    icon: "calendar",
                    title: "Date & Time",
                    value: formatDateTime(party.startTime)
                )
                
                TicketDetailRow(
                    icon: "location.fill",
                    title: "Location",
                    value: "\(party.locationName)\n\(party.address)"
                )
                
                TicketDetailRow(
                    icon: "person.fill",
                    title: "Host",
                    value: "@\(party.hostHandle)"
                )
                
                TicketDetailRow(
                    icon: "dollarsign.circle.fill",
                    title: "Ticket Price",
                    value: "$\(Int(party.ticketPrice))"
                )
                
                if !party.description.isEmpty {
                    TicketDetailRow(
                        icon: "text.alignleft",
                        title: "Description",
                        value: party.description
                    )
                }
            }
        }
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy\nh:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Ticket Detail Row
struct TicketDetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.pink)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.body)
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Action Buttons Section
struct ActionButtonsSection: View {
    let party: Afterparty
    
    var body: some View {
        VStack(spacing: 12) {
            if !party.googleMapsLink.isEmpty {
                Link(destination: URL(string: party.googleMapsLink)!) {
                    HStack {
                        Image(systemName: "map.fill")
                        Text("Get Directions")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            
            Button("Share Ticket") {
                // TODO: Share functionality
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6).opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(12)
            
            Button("Contact Host") {
                // TODO: Contact functionality
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.pink)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}
