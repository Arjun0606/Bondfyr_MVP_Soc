import SwiftUI
import FirebaseAuth

struct UserPartyProfileView: View {
    @Binding var isPresented: Bool
    let user: AppUser
    let eventId: String
    
    @StateObject private var likeManager = LikeManager.shared
    @State private var likers: [AppUser] = []
    @State private var hasLiked: Bool = false
    @State private var showConnectionSheet = false
    
    private var currentUserId: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        VStack(spacing: 20) {
            // User Header
            VStack {
                Circle()
                    .fill(Color.purple.opacity(0.8))
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
                
                // Show username if available
                if let username = user.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.top)

            // Simple Stats Display
            ReputationView(user: user)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

            // Party Connections Info
            VStack(spacing: 12) {
                Text("Party Connections")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 16) {
                    VStack {
                        Text("\(likers.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Liked by")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    VStack {
                        Text("\(user.totalPartyHours ?? 0)h")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Party Hours")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Actions
            HStack(spacing: 15) {
                // Like/Unlike Button
                Button(action: toggleLike) {
                    Text(hasLiked ? "Liked" : "Like")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(hasLiked ? Color.purple : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                // Connect Button (simplified from rating)
                Button(action: { showConnectionSheet = true }) {
                    Text("Connect")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear(perform: fetchData)
        .sheet(isPresented: $showConnectionSheet) {
            ConnectionRequestView(
                isPresented: $showConnectionSheet,
                targetUser: user,
                eventId: eventId
            )
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
        
        if hasLiked {
            // Unlike logic could be implemented here
            print("Unlike functionality not yet implemented")
        } else {
            likeManager.likeUser(likerId: likerId, likedId: user.uid, eventId: eventId)
            hasLiked = true
            
            // Update connections count for the liked user
            ReputationManager.shared.updateSocialConnection(
                for: user.uid,
                platform: "connections",
                connected: true
            )
        }
    }
}

// MARK: - Connection Request View (Simplified replacement for rating)
struct ConnectionRequestView: View {
    @Binding var isPresented: Bool
    let targetUser: AppUser
    let eventId: String
    
    @State private var message: String = ""
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 16) {
                    Text("Connect with \(targetUser.name)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Send a friendly connection request to stay in touch after the party!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Message Box
                VStack(alignment: .leading, spacing: 8) {
                    Text("Optional Message")
                        .font(.headline)
                    
                    TextField("Say something nice...", text: $message, axis: .vertical)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .lineLimit(3...6)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    Button(action: sendConnectionRequest) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Send Connection Request")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(isSubmitting)
                    
                    Button("Maybe Later") {
                        isPresented = false
                    }
                    .foregroundColor(.gray)
                }
                .padding()
            }
            .navigationBarItems(
                trailing: Button("Cancel") {
                    isPresented = false
                }
            )
        }
    }
    
    private func sendConnectionRequest() {
        isSubmitting = true
        
        // Simulate connection request (replace with actual implementation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSubmitting = false
            isPresented = false
            
            // Show success feedback
            // This would send a notification or save to database
            print("Connection request sent to \(targetUser.name)")
        }
    }
} 