import SwiftUI

struct PartyRatingView: View {
    let afterparty: Afterparty
    let onSubmit: (PartyRating) -> Void
    let onSkip: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var partyRating: Int = 5
    @State private var hostRating: Int = 5
    @State private var comments: String = ""
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.yellow)
                    
                    Text("Rate Your Experience")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("How was \(afterparty.title)?")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Party Rating
                        VStack(spacing: 16) {
                            Text("Overall Party Experience")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            StarRatingView(rating: $partyRating)
                            
                            Text(partyRatingText)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                        
                        // Host Rating
                        VStack(spacing: 16) {
                            Text("Rate the Host")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            StarRatingView(rating: $hostRating)
                            
                            Text(hostRatingText)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                        
                        // Comments
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Any comments? (Optional)")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextEditor(text: $comments)
                                .frame(minHeight: 80)
                                .padding(8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                // Buttons
                VStack(spacing: 12) {
                    Button(action: submitRating) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(isSubmitting ? "Submitting..." : "Submit Rating")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isSubmitting)
                    
                    Button("Skip for Now") {
                        onSkip()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.gray)
                }
                .padding(.horizontal)
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private var partyRatingText: String {
        switch partyRating {
        case 1: return "Poor experience"
        case 2: return "Below expectations"
        case 3: return "Average party"
        case 4: return "Great time!"
        case 5: return "Amazing party!"
        default: return ""
        }
    }
    
    private var hostRatingText: String {
        switch hostRating {
        case 1: return "Poor host"
        case 2: return "Below average host"
        case 3: return "Good host"
        case 4: return "Great host"
        case 5: return "Excellent host!"
        default: return ""
        }
    }
    
    private func submitRating() {
        guard let currentUser = authViewModel.currentUser else { return }
        
        isSubmitting = true
        
        let rating = PartyRating(
            partyId: afterparty.id,
            partyTitle: afterparty.title,
            hostId: afterparty.userId,
            hostName: afterparty.hostHandle,
            guestId: currentUser.uid,
            guestName: currentUser.name,
            partyRating: partyRating,
            hostRating: hostRating,
            comments: comments.isEmpty ? nil : comments,
            partyDate: afterparty.startTime
        )
        
        onSubmit(rating)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Star Rating Component
struct StarRatingView: View {
    @Binding var rating: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { star in
                Button(action: {
                    rating = star
                }) {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundColor(star <= rating ? .yellow : .gray)
                }
            }
        }
    }
}

#Preview {
    PartyRatingView(
        afterparty: Afterparty.sampleData,
        onSubmit: { _ in },
        onSkip: { }
    )
    .environmentObject(AuthViewModel())
} 