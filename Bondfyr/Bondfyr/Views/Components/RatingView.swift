import SwiftUI

struct RatingView: View {
    @Binding var isPresented: Bool
    let eventId: String
    let raterId: String
    let ratedUser: AppUser // The user being rated
    let ratedUserType: String // "host" or "guest"
    
    @State private var rating: Double = 3.0
    @State private var comment: String = ""
    @State private var isSubmitting = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rate \(ratedUser.name)")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Star Rating
            HStack {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index > Int(rating) ? "star" : "star.fill")
                        .foregroundColor(.yellow)
                        .onTapGesture {
                            rating = Double(index)
                        }
                }
            }
            .font(.largeTitle)
            
            // Comment Box
            TextField("Leave a comment (optional)", text: $comment)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            // Submit Button
            Button(action: submitRating) {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Submit Rating")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.pink)
                        .cornerRadius(8)
                }
            }
            .disabled(isSubmitting)
            
            Spacer()
        }
        .padding()
    }
    
    private func submitRating() {
        isSubmitting = true
        ReputationManager.shared.submitRating(
            raterId: raterId,
            ratedId: ratedUser.uid,
            eventId: eventId,
            rating: rating,
            comment: comment.isEmpty ? nil : comment,
            ratedUserType: ratedUserType
        )
        
        // Give a small delay for the user to see the change, then dismiss.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSubmitting = false
            isPresented = false
        }
    }
} 