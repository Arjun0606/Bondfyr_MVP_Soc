import SwiftUI
import FirebaseFirestore

struct PostPartyRatingView: View {
    let afterparty: Afterparty
    let onRatingSubmitted: () -> Void
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    @State private var hostRating: Double = 5.0
    @State private var partyRating: Double = 5.0
    @State private var feedback: String = ""
    @State private var isSubmitting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let ratingCategories = [
        ("Organization", "How well was the party organized?"),
        ("Atmosphere", "Was the vibe and energy good?"),
        ("Value", "Was the party experience worthwhile?"),
        ("Safety", "Did you feel safe at the party?"),
        ("Communication", "How responsive was the host?")
    ]
    
    @State private var categoryRatings: [String: Double] = [
        "Organization": 5.0,
        "Atmosphere": 5.0,
        "Value": 5.0,
        "Safety": 5.0,
        "Communication": 5.0
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Host Rating
                    hostRatingSection
                    
                    // Category Ratings
                    categoryRatingsSection
                    
                    // Overall Party Rating
                    partyRatingSection
                    
                    // Feedback
                    feedbackSection
                    
                    // Submit Button
                    submitButton
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.gray)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Rate Party")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("How was the party?")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 4) {
                Text(afterparty.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Hosted by @\(afterparty.hostHandle)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(afterparty.locationName)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
    }
    
    private var hostRatingSection: some View {
        VStack(spacing: 16) {
            Text("Rate the Host")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("How did @\(afterparty.hostHandle) do as a host?")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            // Star Rating for Host
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: {
                        hostRating = Double(star)
                    }) {
                        Image(systemName: star <= Int(hostRating) ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundColor(star <= Int(hostRating) ? .yellow : .gray)
                    }
                }
            }
            
            Text("\(Int(hostRating)) out of 5 stars")
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
    }
    
    private var categoryRatingsSection: some View {
        VStack(spacing: 16) {
            Text("Detailed Ratings")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                ForEach(ratingCategories, id: \.0) { category, description in
                    CategoryRatingRow(
                        category: category,
                        description: description,
                        rating: Binding(
                            get: { categoryRatings[category] ?? 5.0 },
                            set: { categoryRatings[category] = $0 }
                        )
                    )
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
    }
    
    private var partyRatingSection: some View {
        VStack(spacing: 16) {
            Text("Overall Party Experience")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("How would you rate this party overall?")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Star Rating for Party
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: {
                        partyRating = Double(star)
                    }) {
                        Image(systemName: star <= Int(partyRating) ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundColor(star <= Int(partyRating) ? .pink : .gray)
                    }
                }
            }
            
            Text("\(Int(partyRating)) out of 5 stars")
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
    }
    
    private var feedbackSection: some View {
        VStack(spacing: 16) {
            Text("Additional Feedback (Optional)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            TextEditor(text: $feedback)
                .frame(height: 100)
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .foregroundColor(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            Text("Share what went well or what could be improved")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    private var submitButton: some View {
        Button(action: submitRating) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Submit Rating")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.pink)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isSubmitting)
    }
    
    private func submitRating() {
        isSubmitting = true
        
        Task {
            do {
                try await submitPartyRating()
                
                await MainActor.run {
                    onRatingSubmitted()
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isSubmitting = false
                }
            }
        }
    }
    
    private func submitPartyRating() async throws {
        guard let currentUserId = authViewModel.currentUser?.uid else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let db = Firestore.firestore()
        
        // Calculate average category rating
        let avgCategoryRating = categoryRatings.values.reduce(0, +) / Double(categoryRatings.count)
        
        // Calculate if party was successful (>=50% capacity AND avg rating >= 3.5)
        let capacityPercentage = Double(afterparty.confirmedGuestsCount) / Double(afterparty.maxGuestCount)
        let isSuccessfulParty = capacityPercentage >= 0.5 && avgCategoryRating >= 3.5
        
        // Create rating document
        let ratingData: [String: Any] = [
            "afterpartyId": afterparty.id,
            "hostId": afterparty.userId,
            "guestId": currentUserId,
            "hostRating": hostRating,
            "partyRating": partyRating,
            "categoryRatings": categoryRatings,
            "averageCategoryRating": avgCategoryRating,
            "feedback": feedback,
            "isSuccessfulParty": isSuccessfulParty,
            "capacityPercentage": capacityPercentage,
            "createdAt": Timestamp(date: Date()),
            "partyTitle": afterparty.title,
            "partyLocation": afterparty.locationName
        ]
        
        // Add rating to ratings collection
        try await db.collection("ratings").addDocument(data: ratingData)
        
        // Update host's rating stats
        try await updateHostRatingStats(hostId: afterparty.userId, newRating: hostRating, isSuccessful: isSuccessfulParty)
        
        // Update afterparty with completion status
        try await db.collection("afterparties").document(afterparty.id).updateData([
            "isRated": true,
            "averageRating": avgCategoryRating,
            "isSuccessfulParty": isSuccessfulParty
        ])
    }
    
    private func updateHostRatingStats(hostId: String, newRating: Double, isSuccessful: Bool) async throws {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(hostId)
        
        try await db.runTransaction { transaction, errorPointer in
            do {
                let userDoc = try transaction.getDocument(userRef)
                guard let userData = userDoc.data() else {
                    throw NSError(domain: "FirestoreError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User document not found"])
                }
                
                let currentRating = userData["hostRating"] as? Double ?? 0.0
                let currentCount = userData["hostRatingsCount"] as? Int ?? 0
                let currentSuccessfulParties = userData["successfulPartiesCount"] as? Int ?? 0
                
                // Calculate new average rating
                let totalRating = (currentRating * Double(currentCount)) + newRating
                let newCount = currentCount + 1
                let newAverageRating = totalRating / Double(newCount)
                
                // Update successful parties count if this was successful
                let newSuccessfulCount = isSuccessful ? currentSuccessfulParties + 1 : currentSuccessfulParties
                
                // Check if host should be verified (4+ successful parties with good ratings)
                let shouldBeVerified = newSuccessfulCount >= 4 && newAverageRating >= 3.5
                
                // Update user document
                transaction.updateData([
                    "hostRating": newAverageRating,
                    "hostRatingsCount": newCount,
                    "successfulPartiesCount": newSuccessfulCount,
                    "isHostVerified": shouldBeVerified
                ], forDocument: userRef)
                
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
}

struct CategoryRatingRow: View {
    let category: String
    let description: String
    @Binding var rating: Double
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(category)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Button(action: {
                            rating = Double(star)
                        }) {
                            Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(star <= Int(rating) ? .yellow : .gray)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
} 