import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UserNotifications
import CoreLocation

/// CLEAN HOST PARTY CONTROLS - Includes cancel party button
struct HostPartyControls: View {
    let afterparty: Afterparty
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    
    @State private var showingGuestList = false
    @State private var showingShareSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingEditSheet = false
    @State private var isDeleting = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Primary Actions Row
            HStack(spacing: 12) {
                // Manage Guests Button
                Button(action: { showingGuestList = true }) {
                    HStack {
                        Image(systemName: "person.2.fill")
                        Text("Manage Guests (\(pendingRequestCount))")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                // Share Button
                Button(action: { showingShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .padding()
                        .background(Color.gray)
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
                        Text("Edit Party")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                    )
                }
                
                // Cancel Party Button
                Button(action: { showingDeleteConfirmation = true }) {
                    HStack {
                        if isDeleting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.red)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                        }
                        Text("Cancel Party")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red.opacity(0.5), lineWidth: 1)
                    )
                }
                .disabled(isDeleting)
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
        .alert("Cancel Party?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await cancelParty()
                }
            }
        } message: {
            Text("This will cancel your party and refund all guests. This action cannot be undone.")
        }
    }
    
    // MARK: - Computed Properties
    
    private var pendingRequestCount: Int {
        afterparty.guestRequests.filter { $0.approvalStatus == .pending }.count
    }
    
    // MARK: - Actions
    
    private func cancelParty() async {
        isDeleting = true
        
        do {
            try await afterpartyManager.deleteAfterparty(afterparty)
            
            // Send notifications to all guests about cancellation
            await notifyGuestsOfCancellation()
            
            await MainActor.run {
                isDeleting = false
                // The view should dismiss or navigate back automatically when party is deleted
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                print("❌ Error canceling party: \(error)")
            }
        }
    }
    
    private func notifyGuestsOfCancellation() async {
        // Notify all guests that the party was cancelled
        for request in afterparty.guestRequests {
            await sendCancellationNotification(to: request.userId)
        }
    }
    
    private func sendCancellationNotification(to userId: String) async {
        let content = UNMutableNotificationContent()
        content.title = "🚫 Party Cancelled"
        content.body = "The party '\(afterparty.title)' has been cancelled by the host. You will receive a full refund."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "party_cancelled_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Sent cancellation notification to guest \(userId)")
        } catch {
            print("❌ Failed to send cancellation notification: \(error)")
        }
    }
}

// MARK: - Preview
struct HostPartyControls_Previews: PreviewProvider {
    static var previews: some View {
        HostPartyControls(afterparty: Afterparty(
            id: "test",
            userId: "host123",
            hostHandle: "testhost",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            radius: 100,
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            city: "Test City",
            locationName: "Test Location",
            description: "Test party",
            address: "123 Test St",
            googleMapsLink: "",
            vibeTag: "party",
            activeUsers: [],
            pendingRequests: [],
            createdAt: Date(),
            title: "Test Party",
            ticketPrice: 25.0,
            coverPhotoURL: nil,
            maxGuestCount: 50,
            visibility: .publicFeed,
            approvalType: .manual,
            ageRestriction: nil,
            maxMaleRatio: 0.7,
            legalDisclaimerAccepted: true,
            guestRequests: [],
            earnings: 0,
            bondfyrFee: 0,
            venmoHandle: nil,
            chatEnded: false,
            chatEndedAt: nil,
            statsProcessed: false,
            statsProcessedAt: nil
        ))
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
        .padding()
    }
} 