import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @State private var instagramHandle: String = ""
    @State private var avatarURL: String? = nil
    @State private var isLoading = true
    @State private var error: String? = nil
    @State private var badges: [String] = [] // Placeholder for badge codes
    @State private var leaderboard: [(String, Int)] = [] // Placeholder for leaderboard (handle, score)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView()
                } else if let error = error {
                    Text(error).foregroundColor(.red)
                } else {
                    // IG avatar
                    if let url = avatarURL, let imgURL = URL(string: url) {
                        AsyncImage(url: imgURL) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.pink, lineWidth: 3))
                        .onTapGesture { openInstagram() }
                    } else {
                        Circle().fill(Color.gray.opacity(0.2)).frame(width: 100, height: 100)
                    }
                    // IG handle
                    Button(action: openInstagram) {
                        Text("@\(instagramHandle)")
                            .font(.title2)
                            .foregroundColor(.pink)
                    }
                    // Badges (placeholder)
                    if !badges.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Badges")
                                .font(.headline)
                                .foregroundColor(.white)
                            HStack {
                                ForEach(badges, id: \ .self) { badge in
                                    Text(badge)
                                        .padding(6)
                                        .background(Color.purple)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    // Leaderboard (placeholder)
                    if !leaderboard.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Leaderboard")
                                .font(.headline)
                                .foregroundColor(.white)
                            ForEach(leaderboard, id: \ .0) { (handle, score) in
                                HStack {
                                    Text("@\(handle)")
                                        .foregroundColor(.pink)
                                    Spacer()
                                    Text("\(score) pts")
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    // Leaderboard link
                    NavigationLink(destination: LeaderboardView()) {
                        HStack {
                            Image(systemName: "crown.fill").foregroundColor(.yellow)
                            Text("Leaderboard")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                    }
                    // Pre-Game link
                    NavigationLink(destination: PreGameView()) {
                        HStack {
                            Image(systemName: "cart.fill").foregroundColor(.green)
                            Text("Pre-Game")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                    }
                }
                Spacer()
            }
            .padding()
            .background(BackgroundGradientView())
            .navigationTitle("Profile")
            .onAppear { fetchProfile() }
        }
    }
    func fetchProfile() {
        isLoading = true
        error = nil
        guard let userId = Auth.auth().currentUser?.uid else {
            error = "Not logged in"; isLoading = false; return
        }
        Firestore.firestore().collection("users").document(userId).getDocument { doc, err in
            isLoading = false
            if let err = err {
                error = err.localizedDescription
                return
            }
            let data = doc?.data() ?? [:]
            instagramHandle = data["instagramHandle"] as? String ?? "unknown"
            avatarURL = data["avatarURL"] as? String
            badges = data["badges"] as? [String] ?? []
            // Optionally fetch leaderboard here
        }
    }
    func openInstagram() {
        let url = URL(string: "https://instagram.com/\(instagramHandle)")!
        UIApplication.shared.open(url)
    }
} 