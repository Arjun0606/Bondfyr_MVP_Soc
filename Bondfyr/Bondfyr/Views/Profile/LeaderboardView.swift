import SwiftUI

struct LeaderboardEntry: Identifiable {
    let id: String
    let handle: String
    let avatarURL: String?
    let likeCount: Int
}

enum LeaderboardScope: String, CaseIterable {
    case city = "City"
    case country = "Country"
    case continent = "Continent"
    case world = "World"
}

struct LeaderboardView: View {
    @State private var entries: [LeaderboardEntry] = []
    @State private var selectedScope: LeaderboardScope = .city
    @State private var isLoading = false
    @State private var error: String? = nil
    @ObservedObject var cityManager = CityManager.shared

    var body: some View {
        VStack {
            Picker("Scope", selection: $selectedScope) {
                ForEach(LeaderboardScope.allCases, id: \ .self) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

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
        .background(BackgroundGradientView())
        .navigationTitle("Leaderboard")
        .onAppear { fetchLeaderboard() }
        .onChange(of: selectedScope) { _ in fetchLeaderboard() }
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