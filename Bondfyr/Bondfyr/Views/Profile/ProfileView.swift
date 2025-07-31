import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showingLogoutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var showEditProfile = false
    @State private var showAchievements = false
    @State private var showNewAchievementNotification = false
    @State private var newAchievement: SimpleAchievement?
    @State private var showVerificationGuide = false
    @State private var showSettings = false
    @State private var showHelpSupport = false
    @State private var userAchievements: [SimpleAchievement] = []
    
    // Simplified computed properties using new AppUser model
    private var totalAttendedParties: Int {
        authViewModel.currentUser?.partiesAttended ?? 0
    }
    
    private var totalHostedParties: Int {
        authViewModel.currentUser?.partiesHosted ?? 0
    }
    
    private var totalPartyHours: Int {
        authViewModel.currentUser?.totalPartyHours ?? 0
    }
    
    private var accountAgeDays: Int {
        authViewModel.currentUser?.accountAgeDays ?? 0
    }
    
    private var totalAchievements: Int {
        userAchievements.count
    }
    
    // Verification status
    private var isHostVerified: Bool {
        authViewModel.currentUser?.isHostVerified ?? false
    }
    
    private var isGuestVerified: Bool {
        authViewModel.currentUser?.isGuestVerified ?? false
    }
    
    // Progress towards verification (simplified thresholds)
    private var hostVerificationProgress: Double {
        min(Double(totalHostedParties) / 3.0, 1.0) // 3 parties needed for host verification
    }
    
    private var guestVerificationProgress: Double {
        min(Double(totalAttendedParties) / 5.0, 1.0) // 5 parties needed for guest verification
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
                        
                        // Simple Achievements Preview
                        achievementsPreview
                        
                        // Stats with Progress Indicators
                        statsSection
                        
                        // Settings
                        settingsSection
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadUserAchievements()
            setupAchievementNotifications()
        }
        .sheet(isPresented: $showEditProfile) {
            ProfileFormView()
        }
        .sheet(isPresented: $showAchievements) {
            SimpleAchievementsView(achievements: userAchievements)
            }
            .sheet(isPresented: $showVerificationGuide) {
                VerificationGuideView(isPresented: $showVerificationGuide)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showHelpSupport) {
            HelpSupportView()
        }
        .alert(isPresented: $showingLogoutAlert) {
            Alert(
                title: Text("Sign Out"),
                message: Text("Are you sure you want to sign out?"),
                primaryButton: .destructive(Text("Sign Out")) {
                    authViewModel.logout()
                },
                secondaryButton: .cancel()
            )
        }
        .alert(isPresented: $showingDeleteAccountAlert) {
            Alert(
                title: Text("Delete Account"),
                message: Text("This action cannot be undone. All your data will be permanently deleted."),
                primaryButton: .destructive(Text("Delete")) {
                    authViewModel.deleteAccount { error in
                            if let error = error {
                            print("❌ Delete account error: \(error)")
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .overlay(
            // Achievement notification
            Group {
                if showNewAchievementNotification, let achievement = newAchievement {
                    VStack {
                Spacer()
                        SimpleAchievementToastView(achievement: achievement, isPresented: $showNewAchievementNotification)
                            .padding()
                    }
                }
            }
        )
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile Image
            if let avatarURL = authViewModel.currentUser?.avatarURL, !avatarURL.isEmpty {
                AsyncImage(url: URL(string: avatarURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                        .fill(Color.pink.opacity(0.8))
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            )
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                .overlay(Circle().stroke(Color.pink, lineWidth: 3))
                } else {
                    Circle()
                    .fill(Color.pink.opacity(0.8))
                        .frame(width: 100, height: 100)
                        .overlay(
                        Text(authViewModel.currentUser?.name.prefix(1).uppercased() ?? "?")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
            }
            
            // User Info
            VStack(spacing: 8) {
                HStack {
                    Text(authViewModel.currentUser?.name ?? "Unknown")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    
                    // Verification badges
                    if isHostVerified {
                        Text("🏆")
                            .help("Verified Host")
                    }
                    
                    if isGuestVerified {
                        Text("⭐")
                            .help("Verified Guest")
                    }
                }
                
                if let username = authViewModel.currentUser?.username, !username.isEmpty {
                    Text("@\(username)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                }
                
                Text(authViewModel.currentUser?.city ?? "Location not set")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                if let bio = authViewModel.currentUser?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            
            // Edit Profile Button
            Button(action: { showEditProfile = true }) {
                Text("Edit Profile")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.pink)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Color.pink.opacity(0.2))
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(spacing: 16) {
            Text("Your Activity")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            HStack(spacing: 20) {
                StatView(
                    value: "\(totalHostedParties)", 
                    label: "Hosted",
                    subtitle: isHostVerified ? "Verified" : "\(max(0, 3 - totalHostedParties)) to verify"
                )
                StatView(
                    value: "\(totalAttendedParties)", 
                    label: "Attended",
                    subtitle: isGuestVerified ? "Verified" : "\(max(0, 5 - totalAttendedParties)) to verify"
                )
                StatView(
                    value: "\(totalPartyHours)h", 
                    label: "Party Time",
                    subtitle: "Hours spent"
                )
                StatView(
                    value: authViewModel.currentUser?.accountAgeDisplayText ?? "New", 
                    label: "Member",
                    subtitle: "Account age"
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
    }
    
    // MARK: - Verification Status
    private var verificationStatusSection: some View {
        VStack(spacing: 16) {
            Text("Verification Progress")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                // Guest verification
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: isGuestVerified ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isGuestVerified ? .green : .gray)
                        Text("Guest Verification")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(totalAttendedParties)/5")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    if !isGuestVerified {
                        ProgressView(value: guestVerificationProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(y: 0.8)
                    }
                }
                
                // Host verification
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: isHostVerified ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isHostVerified ? .green : .gray)
                        Text("Host Verification")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(totalHostedParties)/3")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    if !isHostVerified && totalHostedParties > 0 {
                        ProgressView(value: hostVerificationProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .pink))
                            .scaleEffect(y: 0.8)
                    }
                }
            }
            
            Button(action: { showVerificationGuide = true }) {
                Text("Learn about verification")
                    .font(.caption)
                    .foregroundColor(.pink)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
    }
    
    // MARK: - Simple Achievements Preview
    private var achievementsPreview: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Achievements")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(totalAchievements)")
                        .font(.subheadline)
                    .foregroundColor(.gray)
                Button(action: { showAchievements = true }) {
                    Text("View All")
                        .font(.caption)
                        .foregroundColor(.pink)
                }
            }
            
            if userAchievements.isEmpty {
                emptyAchievementsView
            } else {
                achievementsPreviewGrid
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
    }
    
    private var emptyAchievementsView: some View {
        VStack(spacing: 8) {
            Text("🏆")
                .font(.system(size: 40))
            
            Text("No achievements yet")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("Attend or host your first party to get started!")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
    
    private var achievementsPreviewGrid: some View {
        let previewAchievements = Array(userAchievements.prefix(3))
        
        return HStack(spacing: 12) {
            ForEach(previewAchievements) { achievement in
                SimpleAchievementCell(achievement: achievement)
            }
            
            if userAchievements.count > 3 {
                VStack {
                    Text("+\(userAchievements.count - 3)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    Text("more")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                    .frame(width: 60, height: 60)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(spacing: 16) {
            Text("Settings")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                SettingsRowView(
                    icon: "gearshape.fill",
                    title: "App Settings",
                    action: { showSettings = true }
                )
                
                SettingsRowView(
                    icon: "questionmark.circle.fill",
                    title: "Help & Support",
                    action: { showHelpSupport = true }
                )
                
                SettingsRowView(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Sign Out",
                    isDestructive: true,
                    action: { showingLogoutAlert = true }
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
    }
    
    // MARK: - Helper Functions
    
    private func loadUserAchievements() {
        guard let userId = authViewModel.currentUser?.uid else { return }
        
        ReputationManager.shared.fetchUserAchievements(for: userId) { achievements in
            DispatchQueue.main.async {
                self.userAchievements = achievements
            }
        }
    }
    
    private func setupAchievementNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NewAchievementEarned"),
            object: nil,
            queue: .main
        ) { notification in
            if let achievement = notification.object as? SimpleAchievement {
                self.newAchievement = achievement
                self.showNewAchievementNotification = true
                
                // Auto hide after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showNewAchievementNotification = false
                }
                
                // Reload achievements
                self.loadUserAchievements()
            }
        }
    }
}

// MARK: - Supporting Views

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
        .frame(maxWidth: .infinity)
    }
}

struct SimpleAchievementCell: View {
    let achievement: SimpleAchievement
    
    var body: some View {
        VStack(spacing: 4) {
            Text(achievement.emoji)
                        .font(.system(size: 30))
            
            Text(achievement.displayTitle)
                .font(.caption2)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 60, height: 60)
        .background(Color.pink.opacity(0.2))
        .clipShape(Circle())
    }
}

struct SettingsRowView: View {
    let icon: String
    let title: String
    let isDestructive: Bool
    let action: () -> Void
    
    init(icon: String, title: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isDestructive ? .red : .pink)
                    .frame(width: 20)
                
                Text(title)
                    .foregroundColor(isDestructive ? .red : .white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 8)
        }
    }
} 