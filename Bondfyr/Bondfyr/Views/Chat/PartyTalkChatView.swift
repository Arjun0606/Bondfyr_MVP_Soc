import SwiftUI

struct PartyTalkChatView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var chatManager = ChatManager.shared
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var messageText = ""
    @State private var showingCreatePartySheet = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Party Talk")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.pink)
                                Text(locationManager.currentCity ?? "Loading...")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { showingCreatePartySheet = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Host")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                        }
                    }
                    
                    // Topic suggestions
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            TopicChip(title: "🏠 House Parties")
                            TopicChip(title: "🎉 Tonight's Parties")
                            TopicChip(title: "💰 Party Tips")
                            TopicChip(title: "🎵 DJ Recommendations")
                            TopicChip(title: "🍺 BYOB Parties")
                            TopicChip(title: "🏊 Pool Parties")
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(Color.black)
                
                // Messages
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Welcome message
                        VStack(spacing: 12) {
                            Text("💬 Welcome to Party Talk!")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Connect with other party hosts and guests in \(locationManager.currentCity ?? "your city"). Share party tips, coordinate events, and discover the best house parties!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Sample messages to show party focus
                        SamplePartyMessage(
                            username: "PartyHost_Alex",
                            message: "Hosting a rooftop party tonight! Still 5 spots left for $20 💸",
                            time: "2m ago",
                            isHost: true
                        )
                        
                        SamplePartyMessage(
                            username: "SocialButterfly",
                            message: "Anyone know good DJ recommendations for house parties? Budget around $300",
                            time: "15m ago",
                            isHost: false
                        )
                        
                        SamplePartyMessage(
                            username: "PoolParty_Mike",
                            message: "Pool party this weekend! BYOB, venmo @mike_parties $15",
                            time: "1h ago",
                            isHost: true
                        )
                        
                        // Real messages would load here (commented out until ChatManager is updated)
                        // ForEach(chatManager.messages) { message in
                        //     MessageRow(message: message)
                        // }
                    }
                    .padding()
                }
                
                // Message input
                HStack(spacing: 12) {
                    TextField("Share party updates, ask questions...", text: $messageText)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(25)
                        .foregroundColor(.white)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .padding()
                            .background(messageText.isEmpty ? Color.gray : Color.pink)
                            .clipShape(Circle())
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding()
                .background(Color.black)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingCreatePartySheet) {
            CreateAfterpartyView(
                currentLocation: locationManager.location?.coordinate,
                currentCity: locationManager.currentCity ?? ""
            )
        }
        .task {
            // Load chat functionality when available
            // await chatManager.loadCityChat(for: locationManager.currentCity ?? "")
        }
        .onChange(of: locationManager.location) { newLocation in
            // Reload chat when location changes
            // Task {
            //     await chatManager.loadCityChat(for: locationManager.currentCity ?? "")
            // }
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty,
              let userId = authViewModel.currentUser?.uid,
              let userName = authViewModel.currentUser?.name else { return }
        
        // TODO: Implement party talk message sending
        // Task {
        //     await chatManager.sendMessage(
        //         text: messageText,
        //         userId: userId,
        //         userName: userName,
        //         city: locationManager.currentCity ?? ""
        //     )
        // }
        
        messageText = ""
    }
}

struct TopicChip: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.purple.opacity(0.3))
            .foregroundColor(.purple)
            .cornerRadius(15)
    }
}

struct SamplePartyMessage: View {
    let username: String
    let message: String
    let time: String
    let isHost: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
                         Circle()
                 .fill(isHost ? Color.pink : Color.gray)
                 .frame(width: 40, height: 40)
                .overlay(
                    Text(String(username.prefix(1)))
                        .font(.headline)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(username)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if isHost {
                        Text("HOST")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.pink)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Text(time)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Text(message)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
} 