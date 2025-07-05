import SwiftUI
import FirebaseAuth

struct PartyChatView: View {
    let party: Afterparty
    
    @ObservedObject private var chatManager = PartyChatManager.shared
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader
            
            // Messages
            messagesList
            
            // Input area
            messageInput
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.purple.opacity(0.3)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .navigationTitle("Party Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            chatManager.joinPartyChat(for: party)
        }
        .onDisappear {
            chatManager.leavePartyChat()
        }
    }
    
    // MARK: - Header
    
    private var chatHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(party.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.pink)
                        Text(party.locationName)
                            .foregroundColor(.gray)
                    }
                    .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Image(systemName: "eye.fill")
                            .foregroundColor(.blue)
                        Text("\(chatManager.viewerCount)")
                            .foregroundColor(.blue)
                    }
                    .font(.caption)
                    
                    if !chatManager.canPost {
                        Text("VIEW ONLY")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            .padding(.horizontal)
            .safeTopPadding()
            
            Divider()
                .background(Color.gray.opacity(0.3))
        }
        .background(Color.black.opacity(0.3))
    }
    
    // MARK: - Messages
    
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(chatManager.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: chatManager.messages.count) { _ in
                if let lastMessage = chatManager.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Input
    
    private var messageInput: some View {
        VStack(spacing: 0) {
            if !chatManager.canPost {
                HStack {
                    Image(systemName: "eye.fill")
                        .foregroundColor(.blue)
                    Text("You're watching this party live! Only approved guests can post.")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
            }
            
            HStack {
                TextField("Message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isInputFocused)
                    .disabled(!chatManager.canPost)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(chatManager.canPost ? .pink : .gray)
                }
                .disabled(!chatManager.canPost || messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color.black.opacity(0.3))
        }
    }
    
    // MARK: - Helpers
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        chatManager.sendMessage(text: text)
        messageText = ""
        isInputFocused = false
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        if message.isSystemMessage {
            systemMessageView
        } else {
            userMessageView
        }
    }
    
    private var systemMessageView: some View {
        HStack {
            Spacer()
            Text(message.text)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.pink.opacity(0.3), Color.purple.opacity(0.3)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            Spacer()
        }
    }
    
    private var userMessageView: some View {
        let isCurrentUser = message.userId == Auth.auth().currentUser?.uid
        let isHost = message.userHandle == "HOST"
        
        return HStack {
            if isCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Username
                if !isCurrentUser {
                    Text(message.userHandle)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isHost ? .yellow : .blue)
                }
                
                // Message bubble
                Text(message.text)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        isCurrentUser
                            ? LinearGradient(
                                gradient: Gradient(colors: [Color.pink, Color.purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                    )
                    .cornerRadius(16)
                
                // Timestamp
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity * 0.75, alignment: isCurrentUser ? .trailing : .leading)
            
            if !isCurrentUser {
                Spacer()
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
} 