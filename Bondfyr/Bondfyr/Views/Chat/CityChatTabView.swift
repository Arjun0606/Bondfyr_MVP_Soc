import SwiftUI
import FirebaseFirestore

struct CityChatTabView: View {
    @StateObject private var chatManager = ChatManager.shared
    @State private var message = ""
    @State private var selectedCity = "Pune"
    
    var body: some View {
        ZStack {
            // Solid black background like other screens
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // City Header - Styled like other screens
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.pink)
                        .font(.system(size: 18))
                    Text(selectedCity)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .background(
                    Color.white.opacity(0.05)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.pink.opacity(0.5), lineWidth: 1.5)
                        .shadow(color: .pink.opacity(0.3), radius: 8, x: 0, y: 0)
                )
                .cornerRadius(12)
                .padding()
                
                // Messages or Empty State
                ZStack {
                    if chatManager.messages.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No messages yet")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(chatManager.messages) { message in
                                    MessageBubble(message: message)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Message Input
                HStack(spacing: 12) {
                    TextField("Type a message...", text: $message)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.pink)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.8))
            }
        }
        .navigationBarHidden(true)
    }
    
    private func sendMessage() {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task {
            try? await chatManager.sendMessage(text: message, to: selectedCity)
            message = ""
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isCurrentUser { Spacer() }
            
            VStack(alignment: message.isCurrentUser ? .trailing : .leading, spacing: 2) {
                Text("@\(message.userHandle)")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(message.isCurrentUser ? Color.pink : Color(.systemGray6))
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            
            if !message.isCurrentUser { Spacer() }
        }
    }
} 