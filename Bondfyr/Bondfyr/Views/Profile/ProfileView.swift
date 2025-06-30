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
    @State private var showVerificationGuide = false
    @State private var showSettings = false
    @State private var showHelpSupport = false
    
    // Update computed properties to use actual user data from AuthViewModel
    private var totalAttendedParties: Int {
        authViewModel.currentUser?.attendedPartiesCount ?? 0
    }
    
    private var totalHostedParties: Int {
        authViewModel.currentUser?.hostedPartiesCount ?? 0
    }
    
    private var maxLikes: Int {
        authViewModel.currentUser?.totalLikesReceived ?? 0
    }
    
    private var totalBadges: Int {
        badgeService.userBadges.count
    }
    
    // Verification status
    private var isHostVerified: Bool {
        authViewModel.currentUser?.isHostVerified ?? false
    }
    
    private var isGuestVerified: Bool {
        authViewModel.currentUser?.isGuestVerified ?? false
    }
    
    // Progress towards verification
    private var hostVerificationProgress: Double {
        min(Double(totalHostedParties) / 4.0, 1.0) // 4 parties needed for host verification
    }
    
    private var guestVerificationProgress: Double {
        min(Double(totalAttendedParties) / 8.0, 1.0) // 8 parties needed for guest verification
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        profileHeader
                        
                        // Verification Status Section
                        verificationStatusSection
                        
                        // Badges Preview
                        badgesPreview
                        
                        // Stats with Progress Indicators
                        statsSection
                        
                        // Settings
                        VStack(spacing: 16) {
                            Button(action: { showSettings = true }) {
                                HStack {
                                    Image(systemName: "gearshape.fill")
                                        .foregroundColor(.pink)
                                    Text("Settings")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            
                            Button(action: { showHelpSupport = true }) {
                                HStack {
                                    Image(systemName: "questionmark.circle.fill")
                                        .foregroundColor(.pink)
                                    Text("Help & Support")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            
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
            .sheet(isPresented: $showVerificationGuide) {
                VerificationGuideView(isPresented: $showVerificationGuide)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showHelpSupport) {
                HelpFAQView()
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
    
    // New verification status section
    private var verificationStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Verification Status")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { showVerificationGuide = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("Guide")
                    }
                    .font(.caption)
                    .foregroundColor(.pink)
                }
            }
            
            // Host Verification
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: isHostVerified ? "checkmark.shield.fill" : "shield")
                        .foregroundColor(isHostVerified ? .green : .gray)
                    Text("Host Verification")
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                    Spacer()
                    if isHostVerified {
                        Text("✓ VERIFIED")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
                
                if !isHostVerified {
                    ProgressView(value: hostVerificationProgress)
                        .tint(.pink)
                    Text("\(totalHostedParties)/4 parties hosted • \(4 - totalHostedParties) more to verify")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            // Guest Verification  
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: isGuestVerified ? "checkmark.shield.fill" : "shield")
                        .foregroundColor(isGuestVerified ? .green : .gray)
                    Text("Guest Verification")
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                    Spacer()
                    if isGuestVerified {
                        Text("✓ VERIFIED")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
                
                if !isGuestVerified {
                    ProgressView(value: guestVerificationProgress)
                        .tint(.pink)
                    Text("\(totalAttendedParties)/8 parties attended • \(8 - totalAttendedParties) more to verify")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
    }
    
    // Updated stats section with better context
    private var statsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 40) {
                StatView(
                    value: "\(totalAttendedParties)", 
                    label: "Attended",
                    subtitle: isGuestVerified ? "Verified" : "\(max(0, 8 - totalAttendedParties)) to verify"
                )
                StatView(
                    value: "\(totalHostedParties)", 
                    label: "Hosted",
                    subtitle: isHostVerified ? "Verified" : "\(max(0, 4 - totalHostedParties)) to verify"
                )
                StatView(
                    value: "\(maxLikes)", 
                    label: "Max Likes",
                    subtitle: "From events"
                )
                StatView(
                    value: "\(totalBadges)", 
                    label: "Badges",
                    subtitle: "Earned"
                )
            }
        }
        .padding(.vertical)
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
            
            // User Info with verification badges
            HStack(spacing: 8) {
                Text("@\(authViewModel.currentUser?.name ?? "capedpotato")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if isHostVerified {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                if isGuestVerified {
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            
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
    let subtitle: String?
    
    init(value: String, label: String, subtitle: String? = nil) {
        self.value = value
        self.label = label
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
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