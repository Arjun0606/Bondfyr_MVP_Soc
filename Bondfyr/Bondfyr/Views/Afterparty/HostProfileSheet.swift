import SwiftUI
import FirebaseFirestore
import FirebaseAuth

/// Basic Host Profile Sheet (WITHOUT payment details) - for guest request flow
struct HostProfileSheet: View {
    let afterparty: Afterparty
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var afterpartyManager = AfterpartyManager.shared
    @State private var hostUser: AppUser?
    @State private var isLoading = true
    @State private var showingRequestSheet = false
    
    // MARK: - Computed Properties
    
    private var isCurrentUserHost: Bool {
        return authViewModel.currentUser?.uid == afterparty.userId
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView("Loading host profile...")
                            .padding()
                    } else {
                        // Host Profile Header
                        hostProfileHeader
                        
                        // Social Media (if available)
                        socialMediaSection
                        
                        // Verification Status
                        verificationSection
                        
                        // Host Management Section (only for host viewing their own profile)
                        if isCurrentUserHost {
                            hostManagementSection
                        }
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Host Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.pink)
                }
            }
        }
        .sheet(isPresented: $showingRequestSheet) {
            RequestToJoinSheet(afterparty: afterparty) {
                // Refresh and dismiss after request
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onAppear {
            loadHostData()
        }
    }
    
    // MARK: - Host Profile Header
    
    private var hostProfileHeader: some View {
        VStack(spacing: 16) {
            // Host's Actual Profile Picture
            if let hostUser = hostUser, let avatarURL = hostUser.avatarURL, !avatarURL.isEmpty {
                AsyncImage(url: URL(string: avatarURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.pink, lineWidth: 3))
            } else {
                // Fallback to initials if no profile picture
                Circle()
                    .fill(Color.pink)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Text(hostInitials)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                    .overlay(Circle().stroke(Color.pink, lineWidth: 3))
            }
            
            // Host Handle and Name
            VStack(spacing: 4) {
                Text("@\(afterparty.hostHandle)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if let hostUser = hostUser {
                    Text(hostUser.name)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // Party Host Badge
                Text("Party Host")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.pink)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Basic Information
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About This Host")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                // Host's city/location
                if let hostUser = hostUser, let city = hostUser.city, !city.isEmpty {
                    InfoRow(
                        icon: "location.fill",
                        title: city,
                        subtitle: "Host location",
                        iconColor: .blue
                    )
                }
                
                // Host's bio
                if let hostUser = hostUser, let bio = hostUser.bio, !bio.isEmpty {
                    InfoRow(
                        icon: "person.text.rectangle.fill",
                        title: bio,
                        subtitle: "About the host",
                        iconColor: .pink
                    )
                }
                
                // Contact availability
                if let phoneNumber = afterparty.phoneNumber, !phoneNumber.isEmpty {
                    InfoRow(
                        icon: "phone.fill",
                        title: "Contact Available",
                        subtitle: "Host can be reached by phone",
                        iconColor: .green
                    )
                } else {
                    InfoRow(
                        icon: "phone.slash.fill",
                        title: "Limited Contact",
                        subtitle: "Contact via app only",
                        iconColor: .orange
                    )
                }
                
                // Party details
                InfoRow(
                    icon: "location.fill",
                    title: afterparty.locationName,
                    subtitle: "Party location",
                    iconColor: .blue
                )
                
                InfoRow(
                    icon: "person.3.fill",
                    title: "\(afterparty.maxGuestCount) guests max",
                    subtitle: "Party capacity",
                    iconColor: .purple
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    // MARK: - Social Media
    
    private var socialMediaSection: some View {
        Group {
            if hasAnySocialMedia {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Social Media")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 12) {
                        if let hostUser = hostUser, let instagram = hostUser.instagramHandle, !instagram.isEmpty {
                            SocialMediaRow(
                                platform: "Instagram",
                                handle: instagram,
                                color: .pink,
                                icon: "camera.fill"
                            )
                        }
                        
                        if let hostUser = hostUser, let snapchat = hostUser.snapchatHandle, !snapchat.isEmpty {
                            SocialMediaRow(
                                platform: "Snapchat",
                                handle: snapchat,
                                color: .yellow,
                                icon: "bolt.fill"
                            )
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
        }
    }
    
    // MARK: - Verification Status
    
    private var verificationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Verification")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                // Host verification status
                if let hostUser = hostUser {
                    InfoRow(
                        icon: (hostUser.isHostVerified == true) ? "crown.fill" : "crown",
                        title: (hostUser.isHostVerified == true) ? "Verified Host" : "New Host",
                        subtitle: (hostUser.isHostVerified == true) ? "Trusted party host" : "Building reputation",
                        iconColor: (hostUser.isHostVerified == true) ? .yellow : .gray
                    )
                    
                    InfoRow(
                        icon: (hostUser.isGuestVerified == true) ? "star.fill" : "star",
                        title: (hostUser.isGuestVerified == true) ? "Verified Guest" : "Community Member",
                        subtitle: (hostUser.isGuestVerified == true) ? "Active community member" : "New to community",
                        iconColor: (hostUser.isGuestVerified == true) ? .blue : .gray
                    )
                }
                
                // Phone verification
                InfoRow(
                    icon: afterparty.phoneNumber != nil ? "checkmark.shield.fill" : "shield.slash.fill",
                    title: afterparty.phoneNumber != nil ? "Phone Verified" : "Phone Not Verified",
                    subtitle: afterparty.phoneNumber != nil ? "Host provided phone number" : "No phone number provided",
                    iconColor: afterparty.phoneNumber != nil ? .green : .gray
                )
                
                // Profile completeness
                InfoRow(
                    icon: "person.badge.shield.checkmark.fill",
                    title: "Profile Complete",
                    subtitle: "Host profile has been set up",
                    iconColor: .blue
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    // MARK: - Request to Join Button
    
    private var requestToJoinButton: some View {
        Button(action: { showingRequestSheet = true }) {
            HStack {
                Image(systemName: "person.badge.plus")
                Text("Request to Join Party")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.pink]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Host Management Section
    
    private var hostManagementSection: some View {
        VStack(spacing: 16) {
            // Host Badge
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                Text("You are the host of this party")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            
            // Party Stats
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.blue)
                    Text("Party Capacity")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(afterparty.activeUsers.count)/\(afterparty.maxGuestCount)")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.green)
                    Text("Party Status")
                        .foregroundColor(.gray)
                    Spacer()
                    Text(afterparty.completionStatus == nil ? "Active" : "Ended")
                        .foregroundColor(afterparty.completionStatus == nil ? .green : .gray)
                        .fontWeight(.semibold)
                }
                
                if afterparty.ticketPrice > 0 {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.pink)
                        Text("Ticket Price")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("$\(String(format: "%.0f", afterparty.ticketPrice))")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Supporting Views
    
    private struct InfoRow: View {
        let icon: String
        let title: String
        let subtitle: String
        let iconColor: Color
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
        }
    }
    
    private struct SocialMediaRow: View {
        let platform: String
        let handle: String
        let color: Color
        let icon: String
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(platform)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text("@\(handle)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var hostInitials: String {
        let parts = afterparty.hostHandle.split(separator: " ")
        let initials: String
        if parts.count >= 2 {
            initials = String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        } else {
            initials = String(afterparty.hostHandle.prefix(2))
        }
        return initials.uppercased()
    }
    
    private var hasAnySocialMedia: Bool {
        guard let hostUser = hostUser else { return false }
        let hasInstagram = hostUser.instagramHandle?.isEmpty == false
        let hasSnapchat = hostUser.snapchatHandle?.isEmpty == false
        return hasInstagram || hasSnapchat
    }
    
    // MARK: - Data Fetching
    
    private func loadHostData() {
        Task {
            do {
                // Fetch host user data
                let hostDocument = try await Firestore.firestore()
                    .collection("users")
                    .document(afterparty.userId)
                    .getDocument()
                
                if let data = hostDocument.data(),
                   let user = try? Firestore.Decoder().decode(AppUser.self, from: data) {
                    await MainActor.run {
                        self.hostUser = user
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } catch {
                print("🔴 HOST PROFILE: Error fetching host data: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
} 