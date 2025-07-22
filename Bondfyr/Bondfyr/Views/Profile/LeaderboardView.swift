import SwiftUI
import BondfyrPhotos

struct LeaderboardEntry: Identifiable {
    let id: String
    let handle: String
    let avatarURL: String?
    let likeCount: Int
}

enum LeaderboardType {
    case today
    case cumulative
}

struct LeaderboardView: View {
    @State private var entries: [LeaderboardEntry] = []
    @State private var selectedType: LeaderboardType = .today
    @State private var isLoading = false
    @State private var error: String? = nil
    @ObservedObject var cityManager = CityManager.shared

    var body: some View {
        VStack(alignment: .leading) {
            // Tab text
            Text("Leaderboard Today")
                .font(.system(size: 24))
                .foregroundColor(selectedType == .today ? .pink : Color.gray)
                .onTapGesture {
                    withAnimation {
                        selectedType = .today
                    }
                }
            
            Text("Leaderboard Cumulative")
                .font(.system(size: 24))
                .foregroundColor(selectedType == .cumulative ? .pink : Color.gray)
                .onTapGesture {
                    withAnimation {
                        selectedType = .cumulative
                    }
                }

            if isLoading {
                ProgressView()
            } else if let error = error {
                Text(error).foregroundColor(.red)
            } else {
                List(entries) { entry in
                    HStack {
                        if let url = entry.avatarURL, let imgURL = URL(string: url) {
                            AsyncImage(url: imgURL) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        } else {
                            Circle().fill(Color.gray.opacity(0.2)).frame(width: 40, height: 40)
                        }
                        Text("@\(entry.handle)").foregroundColor(.pink)
                        Spacer()
                        Text("\(entry.likeCount) likes").foregroundColor(.white)
                    }
                }
            }
        }
        .padding(.horizontal)
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .onAppear { fetchLeaderboard() }
        .onChange(of: selectedType) { fetchLeaderboard() }
    }

    func fetchLeaderboard() {
        // TODO: Implement Firestore aggregation logic here.
        // For now, use mock data for testing UI.
        isLoading = false
        error = nil
        entries = [
            LeaderboardEntry(id: "1", handle: "alice", avatarURL: nil, likeCount: 120),
            LeaderboardEntry(id: "2", handle: "bob", avatarURL: nil, likeCount: 90),
            LeaderboardEntry(id: "3", handle: "carol", avatarURL: nil, likeCount: 70)
        ]
    }
} 