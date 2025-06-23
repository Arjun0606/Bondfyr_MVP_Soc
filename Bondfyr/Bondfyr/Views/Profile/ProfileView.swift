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
    @State private var newBadge: UserBadge?
    
    // Update computed properties to use actual counts from badge service
    private var totalAttendedParties: Int {
        badgeService.badgeProgress.partiesAttended
    }
    
    private var totalHostedParties: Int {
        badgeService.badgeProgress.partiesHosted
    }
    
    private var maxLikes: Int {
        badgeService.badgeProgress.totalPhotoLikes
    }
    
    private var totalBadges: Int {
        badgeService.userBadges.filter { $0.isEarned }.count
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        profileHeader
                        
                        // Verification Status - Make this prominent
                        verificationStatusCard
                        
                        // Progress Toward Next Badge
                        if !badgeService.getProgressBadges().isEmpty {
                            nextBadgeProgressCard
                        }
                        
                        // Stats
                        HStack(spacing: 40) {
                            StatView(value: "\(totalAttendedParties)", label: "Attended")
                            StatView(value: "\(totalHostedParties)", label: "Hosted")
                            StatView(value: "\(maxLikes)", label: "Photo Likes")
                            StatView(value: "\(totalBadges)", label: "Badges")
                        }
                        .padding(.vertical)
                        
                        // Badges Preview
                        badgesPreview
                        
                        // Settings
                        VStack(spacing: 12) {
                            NavigationLink(destination: SettingsView()) {
                                SettingsRow(icon: "gear", title: "Settings", subtitle: "App preferences and notifications")
                            }
                            
                            Button(action: { showingLogoutAlert = true }) {
                                SettingsRow(icon: "arrow.right.square", title: "Sign Out", subtitle: "Log out of your account", isDestructive: false)
                            }
                            
                            Button(action: { showingDeleteAccountAlert = true }) {
                                SettingsRow(icon: "trash", title: "Delete Account", subtitle: "Permanently delete your account", isDestructive: true)
                            }
                        }
                        .padding(.top)
                    }
                    .padding()
                }
                .sheet(isPresented: $showBadges) {
                    BadgesView(badges: badgeService.userBadges)
                }
                .alert("Sign Out", isPresented: $showingLogoutAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Sign Out", role: .destructive) {
                        Task {
                            await authViewModel.logout()
                        }
                    }
                } message: {
                    Text("Are you sure you want to sign out?")
                }
                .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        // TODO: Implement account deletion
                    }
                } message: {
                    Text("This action cannot be undone. All your data will be permanently deleted.")
                }
                
                // Badge notification overlay
                if showNewBadgeNotification, let badge = newBadge {
                    Color.black.opacity(0.8)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            showNewBadgeNotification = false
                        }
                    
                    BadgeNotificationView(badge: badge, isPresented: $showNewBadgeNotification)
                }
                
                // Progress notification overlay
                if badgeService.showingProgressNotification {
                    VStack {
                        ProgressNotificationView(text: badgeService.progressNotificationText)
                        Spacer()
                    }
                    .animation(.spring(), value: badgeService.showingProgressNotification)
                }
            }
            .navigationBarHidden(true)
        }
        .onReceive(badgeService.$newlyEarnedBadge) { badge in
            if let badge = badge {
                newBadge = badge
                showNewBadgeNotification = true
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile Picture
            Circle()
                .fill(LinearGradient(gradient: Gradient(colors: [.purple, .pink]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 100, height: 100)
                .overlay(
                    Text(authViewModel.currentUser?.name.prefix(1).uppercased() ?? "U")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(spacing: 4) {
                                    Text(authViewModel.currentUser?.name ?? "User")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Show verification status prominently
                if badgeService.verificationStatus.hasAnyVerification {
                    HStack {
                        Text(badgeService.verificationStatus.verificationEmoji)
                        Text(badgeService.verificationStatus.verificationText)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.yellow)
                    }
                } else {
                    Text("Building reputation...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private var verificationStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("🏅 Verification Status")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 12) {
                // Host Verification
                VerificationStatusItem(
                    emoji: "👑",
                    title: "Host",
                    progress: badgeService.badgeProgress.partiesHosted,
                    requirement: 4,
                    isVerified: badgeService.verificationStatus.isVerifiedHost
                )
                
                // Party Goer Verification
                VerificationStatusItem(
                    emoji: "🎊",
                    title: "Party Goer", 
                    progress: badgeService.badgeProgress.partiesAttended,
                    requirement: 4,
                    isVerified: badgeService.verificationStatus.isVerifiedPartyGoer
                )
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(badgeService.verificationStatus.hasAnyVerification ? Color.yellow.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var nextBadgeProgressCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("🎯 Next Achievement")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Spacer()
            }
            
            if let nextBadge = badgeService.getProgressBadges().first {
                HStack(spacing: 12) {
                    Text(nextBadge.type.emoji)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(nextBadge.name)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(nextBadge.progressText)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        ProgressView(value: nextBadge.progressPercentage)
                            .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                            .scaleEffect(y: 1.5)
                    }
                    
                    Spacer()
                    
                    Text("\(Int(nextBadge.progressPercentage * 100))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    private var badgesPreview: some View {
        VStack(spacing: 16) {
            HStack {
                Text("🏆 Badges")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showBadges = true }) {
                    HStack {
                        Text("View All")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
            }
            
            if badgeService.userBadges.isEmpty {
                emptyBadgesView
            } else {
                badgesPreviewGrid
            }
        }
    }
    
    private var emptyBadgesView: some View {
        VStack(spacing: 12) {
            Text("🌟")
                .font(.system(size: 40))
            
            Text("No badges yet")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("Host or attend parties to earn your first badge!")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
    
    private var badgesPreviewGrid: some View {
        let previewBadges = Array(badgeService.userBadges.filter { $0.isEarned }.prefix(4))
        let lockedBadges = Array(badgeService.userBadges.filter { !$0.isEarned }.prefix(4 - previewBadges.count))
        let displayBadges = previewBadges + lockedBadges
        
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(displayBadges.prefix(4)) { badge in
                BadgePreviewCell(badge: badge)
            }
            
            if badgeService.userBadges.count > 4 {
                VStack {
                    Text("+\(badgeService.userBadges.count - 4)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    Text("more")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(width: 60, height: 60)
                .background(Color(.systemGray6).opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Verification Status Item
struct VerificationStatusItem: View {
    let emoji: String
    let title: String
    let progress: Int
    let requirement: Int
    let isVerified: Bool
    
    private var progressPercentage: Double {
        return min(Double(progress) / Double(requirement), 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(emoji)
                .font(.title)
            
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            if isVerified {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Verified")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            } else {
                VStack(spacing: 4) {
                    Text("\(progress)/\(requirement)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    ProgressView(value: progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                        .scaleEffect(y: 1.0)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6).opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isVerified ? Color.green.opacity(0.5) : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Progress Notification View
struct ProgressNotificationView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding()
            .background(Color.orange)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.top, 50)
    }
}

// MARK: - Badge Notification View (Updated)
struct BadgeNotificationView: View {
    let badge: UserBadge
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack(spacing: 24) {
            Text("🎉 New Badge Earned! 🎉")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                Text(badge.type.emoji)
                    .font(.system(size: 80))
                    .scaleEffect(scale)
                
                VStack(spacing: 8) {
                    Text(badge.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(badge.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                // Perks preview
                VStack(spacing: 8) {
                    Text("✨ Perks Unlocked:")
                        .font(.headline)
                        .foregroundColor(.yellow)
                    
                    Text(badge.type.perk)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.2))
                .cornerRadius(12)
            }
            
            Button(action: { isPresented = false }) {
                Text("Awesome!")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow)
                    .cornerRadius(12)
            }
        }
        .padding(24)
        .background(Color.black.opacity(0.9))
        .cornerRadius(20)
        .padding(.horizontal, 20)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                scale = 1.0
                opacity = 1.0
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
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var isDestructive: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isDestructive ? .red : .purple)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(isDestructive ? .red : .white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
    }
}

struct BadgePreviewCell: View {
    let badge: UserBadge
    
    var body: some View {
        VStack(spacing: 4) {
            Text(badge.type.emoji)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color(hex: badge.level.color).opacity(badge.isEarned ? 0.3 : 0.1))
                )
                .overlay(
                    Circle()
                        .stroke(Color(hex: badge.level.color), lineWidth: 1)
                        .opacity(badge.isEarned ? 1.0 : 0.5)
                )
                .saturation(badge.isEarned ? 1.0 : 0.3)
            
            Text(badge.name)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(badge.isEarned ? .white : .gray)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 60)
    }
} 