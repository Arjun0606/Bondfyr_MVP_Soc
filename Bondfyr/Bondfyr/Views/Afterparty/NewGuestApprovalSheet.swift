import SwiftUI
import FirebaseFirestore
import CoreLocation

struct NewGuestApprovalSheet: View {
    let request: GuestRequest
    let party: Afterparty
    let onApproveWithPayment: () -> Void
    let onApproveWithoutPayment: () -> Void // NEW: VIP/Free entry
    let onDeny: () -> Void
    let onDismiss: () -> Void
    
    @State private var isProcessing = false
    @State private var showingProfile = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    guestInfoSection
                    approvalOptionsSection
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Guest Request")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Close") {
                    onDismiss()
                }
            )
        }
        .disabled(isProcessing)
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("New Guest Request")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Review and decide on this guest request")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var guestInfoSection: some View {
        VStack(spacing: 16) {
            // Guest Basic Info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.userHandle)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(request.userName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Requested \(timeAgoString(from: request.requestedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showingProfile = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "person.circle")
                            .font(.title2)
                        Text("View Profile")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Guest Message
            if !request.introMessage.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message from Guest:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(request.introMessage)
                        .font(.body)
                        .padding(12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // ID Verification (if uploaded)
            if let idURL = request.verificationImageURL, !idURL.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ID Verification Uploaded:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Button(action: {
                        // TODO: Show ID verification image
                    }) {
                        HStack {
                            Image(systemName: "doc.text.image")
                            Text("View ID Verification")
                        }
                        .font(.subheadline)
                        .padding(12)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private var approvalOptionsSection: some View {
        VStack(spacing: 16) {
            Text("How would you like to respond?")
                .font(.headline)
                .padding(.top)
            
            // Option 1: Approve with Payment
            approvalButton(
                title: "Approve with Payment",
                subtitle: "Guest pays $\(Int(party.ticketPrice)) to attend",
                icon: "creditcard.fill",
                color: .green,
                action: {
                    handleApproval(requiresPayment: true)
                }
            )
            
            // Option 2: Approve without Payment (VIP)
            approvalButton(
                title: "Approve without Payment",
                subtitle: "VIP entry - Guest attends for free",
                icon: "star.fill",
                color: .purple,
                action: {
                    handleApproval(requiresPayment: false)
                }
            )
            
            // Option 3: Deny
            approvalButton(
                title: "Deny Request",
                subtitle: "Guest will not be able to attend",
                icon: "xmark.circle.fill",
                color: .red,
                action: {
                    handleDenial()
                }
            )
        }
    }
    
    private func approvalButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isProcessing)
    }
    
    // MARK: - Actions
    
    private func handleApproval(requiresPayment: Bool) {
        print("🟢 NEW APPROVAL: \(requiresPayment ? "With Payment" : "VIP Free Entry") for \(request.userHandle)")
        
        isProcessing = true
        
        if requiresPayment {
            onApproveWithPayment()
        } else {
            onApproveWithoutPayment()
        }
        
        // The parent will handle dismissing
    }
    
    private func handleDenial() {
        print("🔴 NEW DENIAL: Denying request for \(request.userHandle)")
        
        isProcessing = true
        onDeny()
        
        // The parent will handle dismissing
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview
struct NewGuestApprovalSheet_Previews: PreviewProvider {
    static var previews: some View {
        NewGuestApprovalSheet(
            request: GuestRequest(
                id: "test",
                userId: "user1",
                userName: "Test User",
                userHandle: "testuser",
                introMessage: "Hey! Would love to join your party, looks amazing!",
                requestedAt: Date(),
                paymentStatus: .pending,
                approvalStatus: .pending,
                paypalOrderId: nil,
                paymentProofImageURL: nil,
                proofSubmittedAt: nil,
                verificationImageURL: "test-url"
            ),
            party: Afterparty(
                id: "test",
                userId: "host",
                hostHandle: "testhost",
                coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                radius: 100,
                startTime: Date(),
                endTime: Date().addingTimeInterval(7200),
                city: "Test City",
                locationName: "Test Location",
                description: "Test Party",
                address: "123 Test St",
                googleMapsLink: "",
                vibeTag: "House Party",
                activeUsers: [],
                pendingRequests: [],
                createdAt: Date(),
                title: "Test Party",
                ticketPrice: 25.0,
                coverPhotoURL: nil,
                maxGuestCount: 20,
                visibility: .publicFeed,
                approvalType: .manual,
                ageRestriction: nil,
                maxMaleRatio: 0.7,
                legalDisclaimerAccepted: true,
                guestRequests: [],
                earnings: 0,
                bondfyrFee: 0,
                phoneNumber: "555-0123",
                instagramHandle: "testinsta",
                snapchatHandle: "testsnap",
                venmoHandle: "testvenmo",
                zelleInfo: "test@zelle.com",
                cashAppHandle: "$testcash",
                acceptsApplePay: true,
                paymentId: nil,
                paymentStatus: nil,
                listingFeePaid: true
            ),
            onApproveWithPayment: {},
            onApproveWithoutPayment: {},
            onDeny: {},
            onDismiss: {}
        )
    }
} 