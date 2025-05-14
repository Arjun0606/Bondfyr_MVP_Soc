import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import BondfyrPhotos

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showingLogoutAlert = false
    @State private var showingDeleteAccountAlert = false
    @StateObject private var badgeService = BadgeService.shared
    @State private var showBadges = false
    @State private var showNewBadgeNotification = false
    @State private var newBadge: PhotoBadge?
    
    // Update computed properties to use actual counts
    private var totalAttendedParties: Int {
        badgeService.partyAttendanceCount
    }
    
    private var totalHostedParties: Int {
        badgeService.partyHostedCount
    }
    
    private var maxLikes: Int {
        badgeService.totalLikes
    }
    
    private var totalBadges: Int {
        badgeService.userBadges.count
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        profileHeader
                        
                        // Badges Preview
                        badgesPreview
                        
                        // Stats
                        HStack(spacing: 40) {
                            StatView(value: "\(totalAttendedParties)", label: "Attended")
                            StatView(value: "\(totalHostedParties)", label: "Hosted")
                            StatView(value: "\(maxLikes)", label: "Max Likes")
                            StatView(value: "\(totalBadges)", label: "Badges")
                        }
                        .padding(.vertical)
                        
                        // Settings
                        VStack(spacing: 16) {
                            NavigationButton(icon: "gearshape.fill", text: "Settings")
                            NavigationButton(icon: "questionmark.circle.fill", text: "Help & Support")
                            Button(action: { showingLogoutAlert = true }) {
                                HStack {
                                    Image(systemName: "arrow.right.square.fill")
                                        .foregroundColor(.pink)
                                    Text("Logout")
                                            .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                    }
                            Button(action: { showingDeleteAccountAlert = true }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(.red)
                                    Text("Delete Account")
                                    .foregroundColor(.white)
                                        Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showBadges) {
                BadgesView(badges: badgeService.userBadges)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("BadgeEarned"))) { notification in
                if let badge = notification.userInfo?["badge"] as? PhotoBadge {
                    newBadge = badge
                    showNewBadgeNotification = true
                }
            }
            .overlay {
                if showNewBadgeNotification, let badge = newBadge {
                    Color.black.opacity(0.8)
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                    
                    BadgeNotificationView(badge: badge, isPresented: $showNewBadgeNotification)
                        .padding()
                }
            }
            .alert("Logout", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    Task {
                        await authViewModel.logout()
                    }
                }
            } message: {
                Text("Are you sure you want to logout?")
                        }
            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await authViewModel.deleteAccount { error in
                            if let error = error {
                                print("Error deleting account: \(error)")
                            }
                        }
                    }
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile Image
            if let avatarURL = authViewModel.currentUser?.avatarURL,
               let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                    .overlay(Circle().stroke(Color.pink, lineWidth: 2))
            } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 100)
            }
            
            // User Info
            Text("@\(authViewModel.currentUser?.name ?? "capedpotato")")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(authViewModel.currentUser?.city ?? "Pune, Maharashtra, India")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    private var badgesPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Badges")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { showBadges = true }) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundColor(.pink)
                }
            }
            
            if badgeService.userBadges.isEmpty {
                emptyBadgesView
            } else {
                badgesPreviewGrid
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
    }
    
    private var emptyBadgesView: some View {
        VStack(spacing: 8) {
            Image(systemName: "star.circle")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No badges yet")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("Participate in the community to earn badges!")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
    
    private var badgesPreviewGrid: some View {
        let previewBadges = Array(badgeService.userBadges.prefix(3))
        
        return HStack(spacing: 12) {
            ForEach(previewBadges) { badge in
                BadgePreviewCell(badge: badge)
            }
            
            if badgeService.userBadges.count > 3 {
                Text("+\(badgeService.userBadges.count - 3)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .frame(width: 60, height: 60)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }
}

struct StatView: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct NavigationButton: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.pink)
            Text(text)
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct BadgePreviewCell: View {
    let badge: PhotoBadge
    
    var body: some View {
        VStack(spacing: 4) {
            AsyncImage(url: URL(string: badge.imageURL)) { phase in
                switch phase {
                case .empty:
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color(hex: badge.level.color))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color(hex: badge.level.color))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 60, height: 60)
            .background(
                Circle()
                    .fill(Color(hex: badge.level.color).opacity(0.2))
            )
            
            Text(badge.level.rawValue)
                .font(.caption2)
                .foregroundColor(Color(hex: badge.level.color))
        }
    }
} 