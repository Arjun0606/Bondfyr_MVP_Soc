import SwiftUI

struct MessageRow: View {
    let message: ChatMessage
    var onReact: (String) -> Void
    
    @State private var reactions: [String: Int] = [:]
    @ObservedObject private var chatManager = ChatManager.shared
    
    private var isCurrentUser: Bool {
        message.displayName == chatManager.userDisplayName
    }
    
    var body: some View {
        HStack(alignment: .top) {
            if !isCurrentUser {
                // User avatar for messages from others
                userAvatar
                    .padding(.top, 4)
            } else {
                Spacer()
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
                // Message bubble
                messageBubble
                
                // Message metadata
                HStack(spacing: 4) {
                    if !isCurrentUser {
                        Text(message.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                    }
                    
                    Text(chatManager.formatMessageTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .padding(.leading, 4)
                
                // Reactions
                if !reactions.isEmpty {
                    HStack {
                        ForEach(Array(reactions.keys.sorted()), id: \.self) { emoji in
                            if let count = reactions[emoji], count > 0 {
                                Text("\(emoji) \(count)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
            
            if isCurrentUser {
                // User avatar for current user's messages
                userAvatar
                    .padding(.top, 4)
            } else {
                Spacer()
            }
        }
        .onAppear {
            // Randomly assign some reactions for demo purposes
            if Int.random(in: 0...10) > 7 {
                let emojis = ["❤️", "👍", "😂", "🔥"]
                let randomEmoji = emojis.randomElement()!
                reactions = [randomEmoji: Int.random(in: 1...5)]
            }
        }
    }
    
    // Message bubble
    private var messageBubble: some View {
        VStack(alignment: .leading, spacing: 0) {
            if message.isSystemMessage {
                // System message
                Text(message.text)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
            } else {
                // User message
                HStack {
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(isCurrentUser ? .white : .white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                }
                .background(isCurrentUser ? Color.pink.opacity(0.8) : Color.blue.opacity(0.3))
                .cornerRadius(16)
                .contextMenu {
                    Button(action: {
                        // Copy message
                        UIPasteboard.general.string = message.text
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    
                    Button(action: {
                        onReact(message.id)
                    }) {
                        Label("React", systemImage: "face.smiling")
                    }
                }
            }
        }
        .onTapGesture(count: 2) {
            // Double tap to react with a heart
            addReaction(emoji: "❤️")
        }
    }
    
    // User avatar
    private var userAvatar: some View {
        ZStack {
            Circle()
                .fill(isCurrentUser ? Color.pink.opacity(0.8) : Color.blue.opacity(0.5))
                .frame(width: 30, height: 30)
            
            Text(getInitials(from: message.displayName))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    // Get initials from display name
    private func getInitials(from name: String) -> String {
        let words = name.split(separator: " ")
        if words.count > 1, let first = words.first?.first, let last = words.last?.first {
            return "\(first)\(last)"
        } else if let first = name.first {
            return String(first)
        }
        return "?"
    }
    
    // Add reaction to message
    private func addReaction(emoji: String) {
        var count = reactions[emoji] ?? 0
        count += 1
        reactions[emoji] = count
        
        // This would also update in Firestore in a real implementation
        onReact(message.id)
    }
} 