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
    @EnvironmentObject private var tabSelection: TabSelection
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @State private var acceptedParties: [Afterparty] = []
    @State private var isLoading = false
    @State private var selectedParty: Afterparty? = nil
    @State private var showingInviteDetail = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        LoadingSection()
                    } else if acceptedParties.isEmpty {
                        EmptyInvitesSection()
                    } else {
                        VStack(spacing: 24) {
                            if !acceptedParties.isEmpty {
                                AcceptedPartiesSection(
                                    parties: acceptedParties,
                                    onPartyTap: { party in
                                        selectedParty = party
                                        showingInviteDetail = true
                                    }
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationSafeBackground()
            .navigationTitle("Party Invites")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingInviteDetail) {
            if let party = selectedParty {
                PartyInviteDetailView(party: party)
            }
        }
        .task {
            await loadAcceptedParties()
        }
        .onAppear {
            Task {
                await loadAcceptedParties()
            }
        }
    }
    
    private func loadAcceptedParties() async {
        guard let currentUserId = authViewModel.currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get all marketplace afterparties where the current user is in activeUsers (approved)
            let allParties = try await afterpartyManager.getMarketplaceAfterparties()
        
        await MainActor.run {
            let now = Date()
                acceptedParties = allParties.filter { party in
                    // User must be approved (in activeUsers)
                    guard party.activeUsers.contains(currentUserId) else { return false }
                    
                    // Show if party hasn't started yet OR if it's within 12 hours after start
                    let twelveHoursAfterStart = Calendar.current.date(byAdding: .hour, value: 12, to: party.startTime) ?? party.startTime
                    
                    return now < twelveHoursAfterStart
                }
                .sorted { $0.startTime < $1.startTime }
            }
        } catch {
            print("Error loading accepted parties: \(error)")
        }
    }
}

// MARK: - Loading Section
struct LoadingSection: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .pink))
                .scaleEffect(1.5)
            
            Text("Loading your invites...")
                .foregroundColor(.gray)
        }
        .safeTopPadding(16)
    }
}

// MARK: - Empty State
struct EmptyInvitesSection: View {
    @EnvironmentObject private var tabSelection: TabSelection
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 80))
                .foregroundColor(.pink)
            
            VStack(spacing: 12) {
                Text("No party invites yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("When hosts approve your party requests, they'll show up here with all the details you need to join!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Discover Parties") {
                tabSelection.selectedTab = .partyFeed
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
            .foregroundColor(.white)
            .cornerRadius(25)
        }
        .safeTopPadding(12)
    }
}

// MARK: - Accepted Parties Section
struct AcceptedPartiesSection: View {
    let parties: [Afterparty]
    let onPartyTap: (Afterparty) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Party Invites")
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
                    PartyInviteCard(party: party, onTap: { onPartyTap(party) })
                }
            }
        }
    }
}

// MARK: - Party Invite Card
struct PartyInviteCard: View {
    let party: Afterparty
    let onTap: () -> Void
    
    private var inviteStatus: String {
        let now = Date()
        if party.startTime > now {
            return "Upcoming"
        } else {
            let twelveHoursAfterStart = Calendar.current.date(byAdding: .hour, value: 12, to: party.startTime) ?? party.startTime
            if now < twelveHoursAfterStart {
                return "Active"
            } else {
                return "Ended"
            }
        }
    }
    
    private var statusColor: Color {
        switch inviteStatus {
        case "Upcoming": return .blue
        case "Active": return .green
        default: return .gray
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Invite Header
                HStack {
                    VStack(alignment: .leading) {
                    Text(party.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                        Text("Tap to View Invite")
                            .font(.caption)
                            .foregroundColor(.pink)
                    }
                    
                    Spacer()
                    
                    // Status Badge
                    Text(inviteStatus)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor)
                        .cornerRadius(8)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                
                // Invite Body
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        InviteInfoRow(icon: "calendar", text: formatDate(party.startTime))
                        InviteInfoRow(icon: "mappin.circle.fill", text: party.locationName)
                        InviteInfoRow(icon: "person.fill", text: "@\(party.hostHandle)")
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

struct InviteInfoRow: View {
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



// MARK: - Party Invite Detail View
struct PartyInviteDetailView: View {
    let party: Afterparty
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Invite Confirmation Section
                    InviteConfirmationSection(party: party)
                    
                    // Party Details
                    InvitePartyDetailsSection(party: party)
                    
                    // Action Buttons
                    ActionButtonsSection(party: party)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Party Invite")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Invite Confirmation Section
struct InviteConfirmationSection: View {
    let party: Afterparty
    
    var body: some View {
        VStack(spacing: 16) {
            Text("You're Invited!")
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
                        
                        Text("APPROVED")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                )
            
            Text("Your request has been approved! Show this invite to the host when you arrive.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(20)
    }
}

// MARK: - Invite Party Details Section
struct InvitePartyDetailsSection: View {
    let party: Afterparty
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Party Details")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
                         VStack(spacing: 12) {
                InviteDetailRow(
                    icon: "calendar",
                    title: "Date & Time",
                    value: formatDateTime(party.startTime)
                )
                
                InviteDetailRow(
                    icon: "location.fill",
                    title: "Location",
                    value: "\(party.locationName)\n\(party.address)"
                )
                
                InviteDetailRow(
                    icon: "person.fill",
                    title: "Host",
                    value: "@\(party.hostHandle)"
                )
                
                InviteDetailRow(
                    icon: "dollarsign.circle.fill",
                    title: "Entry Fee",
                    value: "$\(Int(party.ticketPrice))"
                )
                
                if !party.description.isEmpty {
                    InviteDetailRow(
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

// MARK: - Invite Detail Row
struct InviteDetailRow: View {
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
            // PRIORITY: Join Party Chat Button
            NavigationLink(destination: PartyChatView(afterparty: party)) {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.title3)
                    Text("Join Party Chat")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(LinearGradient(gradient: Gradient(colors: [.purple, .pink]), startPoint: .leading, endPoint: .trailing))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
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
            
            Button("Share Invite") {
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
