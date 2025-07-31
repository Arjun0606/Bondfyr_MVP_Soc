import SwiftUI
import FirebaseFirestore
import CoreLocation

struct PartyEndButton: View {
    let afterparty: Afterparty
    let onPartyEnd: () -> Void
    
    @State private var showingRatingSheet = false
    @State private var showingConfirmation = false
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingConfirmation = true
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("I'm Done with This Party")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.pink)
                .cornerRadius(10)
            }
        }
        .alert("End Party Experience?", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Rate & Exit") {
                showingRatingSheet = true
            }
            Button("Skip Rating") {
                onPartyEnd()
            }
        } message: {
            Text("Rate your experience before leaving?")
        }
        .sheet(isPresented: $showingRatingSheet) {
            PostPartyRatingView(
                party: afterparty,
                onRatingSubmitted: {
                    onPartyEnd()
                }
            )
        }
    }
}

#Preview {
    PartyEndButton(
        afterparty: Afterparty(
            id: "test",
            userId: "host123",
            hostHandle: "johndoe",
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            radius: 100,
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            city: "Test City",
            locationName: "Test Location",
            description: "Test party",
            address: "123 Test St",
            googleMapsLink: "",
            vibeTag: "House Party",
            activeUsers: [],
            pendingRequests: [],
            createdAt: Date(),
            title: "Epic House Party",
            ticketPrice: 10.0,
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
            phoneNumber: nil,
            instagramHandle: nil,
            snapchatHandle: nil,
            venmoHandle: nil,
            zelleInfo: nil,
            cashAppHandle: nil,
            acceptsApplePay: nil,
            paymentId: nil,
            paymentStatus: nil,
            listingFeePaid: nil,
            statsProcessed: nil,
            statsProcessedAt: nil,
            completionStatus: nil,
            endedAt: nil,
            endedBy: nil,
            ratedBy: nil,
            lastRatedAt: nil
        ),
        onPartyEnd: { }
    )
    .environmentObject(AuthViewModel())
    .preferredColorScheme(.dark)
}