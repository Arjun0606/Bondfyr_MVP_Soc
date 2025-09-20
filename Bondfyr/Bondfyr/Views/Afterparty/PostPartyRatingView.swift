import SwiftUI
import FirebaseFirestore
import Mixpanel

struct PostPartyRatingView: View {
    let party: Afterparty
    let onRatingSubmitted: () -> Void
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var selectedRating: Int = 0
    @State private var comment: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Text("How was the party?")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(party.title)
                                .font(.headline)
                                .foregroundColor(.pink)
                            
                            Text(formatPartyDate(party.startTime))
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.top)
                        
                        // Star Rating
                        VStack(spacing: 16) {
                            Text("Rate your experience")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { star in
                                    Button(action: {
                                        selectedRating = star
                                    }) {
                                        Image(systemName: star <= selectedRating ? "star.fill" : "star")
                                            .font(.system(size: 30))
                                            .foregroundColor(star <= selectedRating ? .yellow : .gray)
                                    }
                                }
                            }
                            .padding()
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(15)
                        
                        // Optional Comment
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Comments (optional)")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextField("Share your thoughts about the party...", text: $comment, axis: .vertical)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                                .lineLimit(3...6)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(15)
                        
                        // Submit Button
                        Button(action: submitRating) {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Submit Rating")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedRating > 0 ? Color.pink : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(selectedRating == 0 || isSubmitting)
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Rate Party")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Skip") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .opacity(0) // Hidden but keeps layout
            )
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Rating Submitted"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    onRatingSubmitted()
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }

    private func submitRating() {
        guard selectedRating > 0 else { return }
        isSubmitting = true
        RatingManager.shared.submitPartyRating(
            partyId: party.id,
            rating: selectedRating,
            comment: comment
        ) { result in
            DispatchQueue.main.async {
                self.isSubmitting = false
                switch result {
                case .success:
                    AnalyticsManager.shared.track("rating_submitted", [
                        "party_id": party.id,
                        "rating": selectedRating
                    ])
                    self.alertMessage = "Thanks for your feedback!"
                    self.showingAlert = true
                    self.onRatingSubmitted()
                    self.presentationMode.wrappedValue.dismiss()
                case .failure(let error):
                    self.alertMessage = error.localizedDescription
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func formatPartyDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func submitRating() {
        guard let userId = authViewModel.currentUser?.uid,
              selectedRating > 0 else { return }
        
        isSubmitting = true
        
        let db = Firestore.firestore()
        let partyRef = db.collection("afterparties").document(party.id)
        
        // Check if user already rated this party
        if let lastRatedPartyId = authViewModel.currentUser?.lastRatedPartyId,
           lastRatedPartyId == party.id {
            alertMessage = "You have already rated this party."
            showingAlert = true
            isSubmitting = false
            return
        }
        
        // Submit rating to Firestore
        let ratingData: [String: Any] = [
            "ratingsSubmitted.\(userId)": selectedRating,
            "lastRatedAt": FieldValue.serverTimestamp()
        ]
        
        partyRef.updateData(ratingData) { error in
            DispatchQueue.main.async {
                isSubmitting = false
                
                if let error = error {
                    print("❌ Error submitting rating: \(error)")
                    alertMessage = "Failed to submit rating. Please try again."
                } else {
                    print("✅ Rating submitted successfully")
                    alertMessage = "Thank you for your feedback!"
                    
                    // Update user's lastRatedPartyId to prevent duplicate ratings
                    updateUserLastRatedParty()
                }
                
                showingAlert = true
            }
        }
    }
    
    private func updateUserLastRatedParty() {
        guard let userId = authViewModel.currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        userRef.updateData([
            "lastRatedPartyId": party.id
        ]) { error in
            if let error = error {
                print("❌ Error updating user lastRatedPartyId: \(error)")
            } else {
                print("✅ User lastRatedPartyId updated")
            }
        }
    }
}

struct PostPartyRatingView_Previews: PreviewProvider {
    static var previews: some View {
        PostPartyRatingView(party: Afterparty.sampleData, onRatingSubmitted: {})
            .environmentObject(AuthViewModel())
    }
} 