import SwiftUI
import FirebaseFirestore

struct CityChatTabView: View {
    @StateObject private var chatManager = ChatManager.shared
    @State private var searchText = ""
    @State private var message = ""
    @State private var selectedCity = "Pune"
    
    var body: some View {
        VStack(spacing: 0) {
            // City Header
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.pink)
                Text(selectedCity)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.black)
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search messages...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding()
            
            if chatManager.messages.isEmpty {
                Spacer()
                VStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No messages yet")
                        .foregroundColor(.gray)
                }
                Spacer()
            } else {
                // Messages List
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(chatManager.messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding()
                }
            }
            
            // Message Input
            HStack {
                TextField("Type a message...", text: $message)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.pink)
                }
            }
            .padding()
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
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
            
            VStack(alignment: message.isCurrentUser ? .trailing : .leading) {
                Text("@\(message.userHandle)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(message.text)
                    .padding(12)
                    .background(message.isCurrentUser ? Color.pink : Color(.systemGray6))
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            
            if !message.isCurrentUser { Spacer() }
        }
    }
} 