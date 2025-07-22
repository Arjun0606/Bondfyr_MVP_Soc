import SwiftUI

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
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.green, Color.blue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(radius: 4)
            }
            
            Text("Tap when you're ready to leave the party")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .alert("End Party Experience?", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Yes, I'm Done") {
                showingRatingSheet = true
            }
        } message: {
            Text("You'll be asked to rate your experience to help improve future parties.")
        }
        .sheet(isPresented: $showingRatingSheet) {
            PartyRatingView(
                afterparty: afterparty,
                onSubmit: handleRatingSubmission,
                onSkip: handleSkipRating
            )
        }
    }
    
    private func handleRatingSubmission(_ rating: PartyRating) {
        print("📝 RATING: Guest submitted rating for party \(afterparty.title)")
        print("📝 RATING: Party: \(rating.partyRating)/5, Host: \(rating.hostRating)/5")
        
        // Save rating to Firestore
        Task {
            await RatingManager.shared.submitRating(rating)
        }
        
        // Mark guest as having ended the party
        onPartyEnd()
    }
    
    private func handleSkipRating() {
        print("⏭️ RATING: Guest skipped rating for party \(afterparty.title)")
        
        // Still mark as ended, just without rating
        onPartyEnd()
    }
}

#Preview {
    PartyEndButton(
        afterparty: Afterparty.sampleData,
        onPartyEnd: { }
    )
    .environmentObject(AuthViewModel())
    .preferredColorScheme(.dark)
} 