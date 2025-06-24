import SwiftUI
import FirebaseAuth

struct UserPartyProfileView: View {
    @Binding var isPresented: Bool
    let user: AppUser
    let eventId: String
    
    @StateObject private var likeManager = LikeManager.shared
    @State private var likers: [AppUser] = []
    @State private var hasLiked: Bool = false
    @State private var showRatingSheet = false
    
    private var currentUserId: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        VStack(spacing: 20) {
            // User Header
            VStack {
                Circle()
                    .fill(Color.pink.opacity(0.8))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(String(user.name.prefix(1)).uppercased())
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                Text(user.name)
                    .font(.title)
                    .fontWeight(.bold)
            }
            .padding(.top)

            // Reputation View
            ReputationView(user: user)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

            // Party Connections
            VStack(alignment: .leading) {
                Text("Party Connections")
                    .font(.headline)
                
                if likers.isEmpty {
                    Text("\(user.name) has no connections at this party yet.")
                        .foregroundColor(.gray)
                        .padding(.top, 5)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(likers, id: \.uid) { liker in
                                VStack {
                                    Circle()
                                        .fill(Color.purple.opacity(0.8))
                                        .frame(width: 50, height: 50)
                                        .overlay(Text(String(liker.name.prefix(1)).uppercased()).foregroundColor(.white))
                                    Text(liker.name.split(separator: " ").first ?? "")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            
            // Action Buttons
            HStack(spacing: 15) {
                // Like/Unlike Button
                Button(action: toggleLike) {
                    Text(hasLiked ? "Liked" : "Like")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(hasLiked ? Color.pink : Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                // Rate Button
                Button(action: { showRatingSheet = true }) {
                    Text("Rate")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear(perform: fetchData)
        .sheet(isPresented: $showRatingSheet) {
            if let raterId = currentUserId {
                RatingView(
                    isPresented: $showRatingSheet,
                    eventId: eventId,
                    raterId: raterId,
                    ratedUser: user,
                    ratedUserType: user.uid == currentUserId ? "host" : "guest"
                )
            }
        }
    }
    
    private func fetchData() {
        // Fetch users who liked this user at this event
        likeManager.fetchLikers(for: user.uid, at: eventId) { fetchedLikers in
            self.likers = fetchedLikers
        }
        
        // Check if the current user has liked this user
        if let likerId = currentUserId {
            likeManager.hasLiked(likerId: likerId, likedId: user.uid, eventId: eventId) { result in
                self.hasLiked = result
            }
        }
    }
    
    private func toggleLike() {
        guard let likerId = currentUserId else { return }
        
        hasLiked.toggle() // Optimistic UI update
        
        if hasLiked {
            likeManager.likeUser(likerId: likerId, likedId: user.uid, eventId: eventId)
        } else {
            likeManager.unlikeUser(likerId: likerId, likedId: user.uid, eventId: eventId)
        }
        
        // Refresh the liker list after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            fetchData()
        }
    }
} 