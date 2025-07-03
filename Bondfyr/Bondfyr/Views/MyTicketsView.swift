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
    @State private var isLoading = false
    @State private var selectedParty: Afterparty? = nil
    @State private var showingTicketDetail = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        LoadingSection()
                    } else if upcomingParties.isEmpty {
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
        }
    }
    
    private func createSampleUserTickets() -> [Afterparty] {
        // Return empty array for TestFlight - no demo tickets
        return []
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
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Ticket Header
                VStack {
                    Text(party.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("Tap to View Details")
                        .font(.caption)
                        .foregroundColor(.pink)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.1))
                
                // Ticket Body
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        TicketInfoRow(icon: "calendar", text: formatDate(party.startTime))
                        TicketInfoRow(icon: "mappin.circle.fill", text: party.locationName)
                    }
                    
                    Spacer()
                    
                    CountdownView(startTime: party.startTime)
                }
                .padding()
            }
            .background(Color(.systemGray6).opacity(0.2))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [.pink, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }
}

struct TicketInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .font(.subheadline)
            Text(text)
                .foregroundColor(.white)
                .font(.subheadline)
        }
    }
}

struct CountdownView: View {
    let startTime: Date
    @State private var timeRemaining: String = ""
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            Text(timeRemaining)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text("Starts In")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .onReceive(timer) { _ in
            updateTimeRemaining()
        }
        .onAppear {
            updateTimeRemaining()
        }
    }
    
    private func updateTimeRemaining() {
        let now = Date()
        let calendar = Calendar.current
        
        if startTime < now {
            timeRemaining = "Now"
            return
        }
        
        let components = calendar.dateComponents([.day, .hour, .minute, .second], from: now, to: startTime)
        
        if let days = components.day, days > 0 {
            timeRemaining = "\(days)d"
        } else if let hours = components.hour, hours > 0 {
            timeRemaining = "\(hours)h"
        } else if let minutes = components.minute, minutes > 0 {
            timeRemaining = "\(minutes)m"
        } else if let seconds = components.second, seconds > 0 {
            timeRemaining = "\(seconds)s"
        } else {
            timeRemaining = "Now"
        }
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
