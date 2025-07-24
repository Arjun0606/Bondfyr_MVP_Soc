import SwiftUI
import FirebaseFirestore
import CoreLocation

/// SIMPLE HOST CONTROLS REPLACEMENT - Use this instead of complex existing ones
struct SimpleHostControls: View {
    let afterparty: Afterparty
    
    var body: some View {
        VStack(spacing: 0) {
            // Party Info Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(afterparty.title)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("at \(afterparty.locationName)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text("$\(Int(afterparty.hostEarnings))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                // Stats Row
                HStack(spacing: 24) {
                    SimpleStatItemView(value: "\(afterparty.confirmedGuestsCount)", label: "Guests")
                    SimpleStatItemView(value: "\(pendingCount)", label: "Pending")
                    SimpleStatItemView(value: afterparty.timeUntilStart, label: "Starts")
                }
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.vertical, 12)
            
            // Host Controls
            HostPartyControls(afterparty: afterparty)
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var pendingCount: Int {
        afterparty.guestRequests.filter { $0.approvalStatus == .pending }.count
    }
}

// MARK: - Simple Stat Item View (renamed to avoid conflicts)
struct SimpleStatItemView: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Preview
struct SimpleHostControls_Previews: PreviewProvider {
    static var previews: some View {
        SimpleHostControls(afterparty: Afterparty(
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