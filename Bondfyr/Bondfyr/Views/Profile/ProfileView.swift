import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showingLogoutAlert = false
    @State private var showingDeleteAccountAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
            VStack(spacing: 24) {
                    // Profile Info
                    VStack(spacing: 16) {
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
                        
                        Text("@\(authViewModel.currentUser?.name ?? "capedpotato")")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text(authViewModel.currentUser?.city ?? "Pune, Maharashtra, India")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    // Stats
                    HStack(spacing: 40) {
                        StatView(value: "0", label: "Attended")
                        StatView(value: "0", label: "Hosted")
                        StatView(value: "0", label: "Max Likes")
                        StatView(value: "0", label: "Badges")
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
            .background(Color.black.edgesIgnoringSafeArea(.all))
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