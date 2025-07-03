import SwiftUI
import FirebaseFirestore

struct UserInfoView: View {
    let userId: String
    @Environment(\.presentationMode) var presentationMode
    @State private var user: AppUser? = nil
    @State private var isLoading = true
    @State private var error: String? = nil
    @State private var hostedParties: [Afterparty] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading {
                    loadingView
                } else if let user = user {
                    userProfileContent(user: user)
                } else {
                    errorView
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.pink)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadUserData()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .pink))
                .scaleEffect(1.5)
            
            Text("Loading profile...")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("User Not Found")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("This user's profile is no longer available.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    @ViewBuilder
    private func userProfileContent(user: AppUser) -> some View {
        VStack(spacing: 24) {
            // Profile Header
            profileHeader(user: user)
            
            // Stats Section
            statsSection(user: user)
            
            // Social Media Section
            socialMediaSection(user: user)
            
            // Verification Status
            verificationSection(user: user)
            
            // Host Performance (if applicable)
            if (user.hostedPartiesCount ?? 0) > 0 {
                hostPerformanceSection(user: user)
            }
            
            // Recent Parties Hosted
            if !hostedParties.isEmpty {
                recentPartiesSection()
            }
        }
        .padding()
    }
    
    private func profileHeader(user: AppUser) -> some View {
        VStack(spacing: 16) {
            // Profile Picture
            if let avatarURL = user.avatarURL, !avatarURL.isEmpty {
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
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    )
                    .overlay(Circle().stroke(Color.pink, lineWidth: 3))
            }
            
            // User Info
            VStack(spacing: 8) {
                HStack {
                    if let username = user.username, !username.isEmpty {
                        Text("@\(username)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    // Verification badges
                    if user.isHostVerified == true {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    }
                    
                    if user.isGuestVerified == true {
                        Image(systemName: "person.badge.shield.checkmark.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                }
                
                Text(user.name)
                    .font(.title3)
                    .foregroundColor(.gray)
                
                HStack {
                    if let gender = user.gender, !gender.isEmpty {
                        Text(gender.capitalized)
                            .foregroundColor(.gray)
                    }
                    
                    if let age = calculateAge(from: user.dob) {
                        Text("• \(age) years old")
                            .foregroundColor(.gray)
                    }
                }
                .font(.subheadline)
                
                Text(user.city ?? "Location not set")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Bio
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
        }
    }
    
    private func statsSection(user: AppUser) -> some View {
        VStack(spacing: 16) {
            Text("Activity Stats")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            HStack(spacing: 30) {
                StatView(
                    value: "\(user.hostedPartiesCount ?? 0)",
                    label: "Parties Hosted",
                    subtitle: (user.isHostVerified == true) ? "✓ Verified" : nil
                )
                
                StatView(
                    value: "\(user.attendedPartiesCount ?? 0)",
                    label: "Parties Attended",
                    subtitle: (user.isGuestVerified == true) ? "✓ Verified" : nil
                )
                
                StatView(
                    value: String(format: "%.1f", user.hostRating ?? 0.0),
                    label: "Host Rating",
                    subtitle: (user.hostRatingsCount ?? 0) > 0 ? "(\(user.hostRatingsCount ?? 0) reviews)" : nil
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
    }
    
    private func socialMediaSection(user: AppUser) -> some View {
        VStack(spacing: 16) {
            Text("Social Media")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            HStack(spacing: 20) {
                // Instagram
                if let instagramHandle = user.instagramHandle, !instagramHandle.isEmpty {
                    Button(action: { openInstagram(handle: instagramHandle) }) {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.pink)
                            Text("@\(instagramHandle)")
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.pink.opacity(0.2))
                        .cornerRadius(20)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.gray)
                        Text("Instagram")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(20)
                }
                
                // Snapchat
                if let snapchatHandle = user.snapchatHandle, !snapchatHandle.isEmpty {
                    Button(action: { openSnapchat(handle: snapchatHandle) }) {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.viewfinder")
                                .foregroundColor(.yellow)
                            Text("Snapchat")
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(20)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .foregroundColor(.gray)
                        Text("Snapchat")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(20)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
    }
    
    private func verificationSection(user: AppUser) -> some View {
        VStack(spacing: 16) {
            Text("Verification Status")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                // Host Verification
                HStack {
                    Image(systemName: (user.isHostVerified == true) ? "checkmark.shield.fill" : "shield.slash")
                        .foregroundColor((user.isHostVerified == true) ? .green : .gray)
                    
                    VStack(alignment: .leading) {
                        Text("Host Verification")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text((user.isHostVerified == true) ? 
                             "Verified host with successful parties" : 
                             "Needs \(max(0, 4 - (user.hostedPartiesCount ?? 0))) more successful parties")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                
                // Guest Verification
                HStack {
                    Image(systemName: (user.isGuestVerified == true) ? "person.badge.shield.checkmark.fill" : "person.badge.shield.checkmark.fill")
                        .foregroundColor((user.isGuestVerified == true) ? .blue : .gray)
                    
                    VStack(alignment: .leading) {
                        Text("Guest Verification")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text((user.isGuestVerified == true) ? 
                             "Verified attendee with good reputation" : 
                             "Needs \(max(0, 8 - (user.attendedPartiesCount ?? 0))) more attended parties")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
    }
    
    private func hostPerformanceSection(user: AppUser) -> some View {
        VStack(spacing: 16) {
            Text("Host Performance")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Average Rating:")
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(user.hostRating ?? 0) ? "star.fill" : "star")
                                .foregroundColor(star <= Int(user.hostRating ?? 0) ? .yellow : .gray)
                                .font(.caption)
                        }
                        Text(String(format: "%.1f", user.hostRating ?? 0.0))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .foregroundColor(.white)
                
                HStack {
                    Text("Total Reviews:")
                    Spacer()
                    Text("\(user.hostRatingsCount ?? 0)")
                        .foregroundColor(.gray)
                }
                .foregroundColor(.white)
                
                HStack {
                    Text("Success Rate:")
                    Spacer()
                    Text("\(calculateSuccessRate())%")
                        .foregroundColor(calculateSuccessRate() >= 70 ? .green : .orange)
                }
                .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
    }
    
    private func recentPartiesSection() -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Parties")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            LazyVStack(spacing: 12) {
                ForEach(Array(hostedParties.prefix(3)), id: \.id) { party in
                    recentPartyCard(party: party)
                }
            }
        }
    }
    
    private func recentPartyCard(party: Afterparty) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(party.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(party.locationName)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(formatDate(party.createdAt))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(Int(party.ticketPrice))")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Text("\(party.confirmedGuestsCount)/\(party.maxGuestCount)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Functions
    
    private func loadUserData() async {
        do {
            let db = Firestore.firestore()
            
            // First try to get user by userId
            let document = try await db.collection("users").document(userId).getDocument()
            
            if let data = document.data() {
                let user = try Firestore.Decoder().decode(AppUser.self, from: data)
                await loadUserSuccessfully(user: user, db: db)
            } else {
                // If user not found by ID, try to find by username/handle
                
                
                // Try to find user by username/handle in case userId doesn't match
                let usersSnapshot = try await db.collection("users")
                    .whereField("username", isEqualTo: userId)
                    .limit(to: 1)
                    .getDocuments()
                
                if let userDoc = usersSnapshot.documents.first {
                    let userData = userDoc.data()
                    let user = try Firestore.Decoder().decode(AppUser.self, from: userData)
                    await loadUserSuccessfully(user: user, db: db)
                } else {
                    await MainActor.run {
                        self.error = "User profile not found"
                        self.isLoading = false
                    }
                }
            }
        } catch {
            
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func loadUserSuccessfully(user: AppUser, db: Firestore) async {
        do {
            // Load hosted parties
            let partiesSnapshot = try await db.collection("afterparties")
                .whereField("userId", isEqualTo: user.uid)
                .order(by: "createdAt", descending: true)
                .limit(to: 3)
                .getDocuments()
            
            let parties = try partiesSnapshot.documents.compactMap { doc -> Afterparty? in
                var docData = doc.data()
                docData["id"] = doc.documentID
                return try? Firestore.Decoder().decode(Afterparty.self, from: docData)
            }
            
            await MainActor.run {
                self.user = user
                self.hostedParties = parties
                self.isLoading = false
            }
        } catch {
            
            await MainActor.run {
                self.user = user
                self.hostedParties = []
                self.isLoading = false
            }
        }
    }
    
    private func calculateAge(from dob: Date) -> Int? {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
        return ageComponents.year
    }
    
    private func calculateSuccessRate() -> Int {
        guard let user = user, (user.hostedPartiesCount ?? 0) > 0 else { return 0 }
        // For now, use a simple calculation based on rating
        return Int(((user.hostRating ?? 0.0) / 5.0) * 100)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func openInstagram(handle: String) {
        let cleanHandle = handle.replacingOccurrences(of: "@", with: "")
        let instagramAppURL = URL(string: "instagram://user?username=\(cleanHandle)")
        let instagramWebURL = URL(string: "https://www.instagram.com/\(cleanHandle)")
        
        if let appURL = instagramAppURL, UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL = instagramWebURL {
            UIApplication.shared.open(webURL)
        }
    }
    
    private func openSnapchat(handle: String) {
        let cleanHandle = handle.replacingOccurrences(of: "@", with: "")
        let snapchatAppURL = URL(string: "snapchat://add/\(cleanHandle)")
        let snapchatWebURL = URL(string: "https://www.snapchat.com/add/\(cleanHandle)")
        
        if let appURL = snapchatAppURL, UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL = snapchatWebURL {
            UIApplication.shared.open(webURL)
        }
    }
} 