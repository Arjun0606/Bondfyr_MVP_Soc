import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UserNotifications
import CoreLocation

/// CLEAN HOST PARTY CONTROLS - End Party only (no cancellation)
struct HostPartyControls: View {
    let afterparty: Afterparty
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    
    // MARK: - Computed Properties for State Management
    
    private var isPartyAlreadyEnded: Bool {
        // Check if party has a completion status (already ended)
        return afterparty.completionStatus != nil
    }
    
    private var canEndParty: Bool {
        let now = Date()
        let oneHourAfterStart = afterparty.startTime.addingTimeInterval(3600) // 1 hour after party start
        // Can end party only after 1 hour from start time and if not already ended
        return now >= oneHourAfterStart && !isPartyAlreadyEnded && !partyActionInProgress
    }
    
    private var timeUntilEndEnabled: String {
        let oneHourAfterStart = afterparty.startTime.addingTimeInterval(3600)
        let timeRemaining = oneHourAfterStart.timeIntervalSinceNow
        
        if timeRemaining <= 0 {
            return ""
        } else if timeRemaining < 3600 {
            return "\(Int(timeRemaining/60))m"
        } else {
            return "\(Int(timeRemaining/3600))h \(Int((timeRemaining.truncatingRemainder(dividingBy: 3600))/60))m"
        }
    }
    
    @State private var showingGuestList = false
    @State private var showingShareSheet = false
    @State private var showingEditSheet = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isEndingParty = false
    @State private var partyActionInProgress = false
    
    var body: some View {
        VStack(spacing: 12) {
            
            // Primary Action Row
            HStack(spacing: 12) {
                // Guest Management Button
                Button(action: { showingGuestList = true }) {
                    HStack {
                        Image(systemName: "person.2.fill")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Guests")
                            if pendingRequestCount > 0 {
                                Text("\(pendingRequestCount) pending")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                // Share Button
                Button(action: { showingShareSheet = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            
            // Secondary Actions Row
            HStack(spacing: 12) {
                // Edit Party Button
                Button(action: { showingEditSheet = true }) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                // End Party Button (triggers rating flow)
                Button(action: { 
                    guard canEndParty else { return }
                    
                    partyActionInProgress = true
                    isEndingParty = true
                    
                    Task {
                        defer {
                            partyActionInProgress = false
                            isEndingParty = false
                        }
                        
                        await RatingManager.shared.hostEndParty(afterparty)
                        
                        await MainActor.run {
                            alertMessage = "🏁 Party ended! Guests will be asked to rate their experience."
                            showingAlert = true
                        }
                    }
                }) {
                    HStack {
                        if isEndingParty {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Ending...")
                        } else if isPartyAlreadyEnded {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Party Ended")
                        } else if canEndParty {
                            Image(systemName: "stop.circle.fill")
                            Text("End Party")
                        } else {
                            Image(systemName: "clock.fill")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("End Party")
                                Text("Available in \(timeUntilEndEnabled)")
                                    .font(.caption2)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(canEndParty ? 0.8 : 0.5))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canEndParty)
            }
        }
        .sheet(isPresented: $showingGuestList) {
            FixedGuestListView(partyId: afterparty.id, originalParty: afterparty)
        }
        .sheet(isPresented: $showingShareSheet) {
            SocialShareSheet(party: afterparty, isPresented: $showingShareSheet)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditAfterpartyView(afterparty: afterparty)
        }
        .alert("Party Status", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Computed Properties
    
    private var pendingRequestCount: Int {
        afterparty.guestRequests.filter { $0.approvalStatus == .pending }.count
    }
}

#Preview {
    HostPartyControls(afterparty: Afterparty.sampleData)
        .environmentObject(AuthViewModel())
} 