import SwiftUI

struct CityChatView: View {
    let city: ChatCity
    
    @ObservedObject private var chatManager = ChatManager.shared
    @State private var messageText = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var isTyping: Bool = false
    @State private var typingUsers: [String] = []
    @State private var showEmojiPicker = false
    @State private var selectedMessageForReaction: String?
    @FocusState private var isInputFocused: Bool
    
    // Simulated typing indicators
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        // Extract main view content to reduce complexity
        mainContent
    }
    
    // Break up complex body into separate computed properties
    private var mainContent: some View {
        ZStack {
            backgroundGradient
            
            VStack(spacing: 0) {
                chatHeader
                chatMessages
                dayDivider
                messageInputArea
            }
            
            emojiPickerOverlay
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundColor(.pink)
                    Text(city.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear(perform: handleAppear)
        .onDisappear {
            chatManager.leaveCityChat()
        }
        .onReceive(timer) { _ in
            simulateRandomUserTyping()
        }
    }
    
    // Background gradient
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.black, Color(red: 0.2, green: 0.08, blue: 0.3)]),
            startPoint: .top,
            endPoint: .bottom
        ).ignoresSafeArea()
    }
    
    // Chat header section
    private var chatHeader: some View {
        VStack(spacing: 6) {
            // Header content
            HStack {
                cityIconView
                
                cityInfoView
                
                Spacer()
                
                Button(action: {
                    // Info about city chat
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.pink)
                }
            }
            .padding(.horizontal)
            
            // Typing indicator
            typingIndicatorView
        }
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.8))
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
    }
    
    // City icon component
    private var cityIconView: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [Color.pink, Color.purple]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 40, height: 40)
            
            Text(String(city.displayName.prefix(1)))
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
    
    // City info component
    private var cityInfoView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(city.displayName)
                .font(.headline)
                .foregroundColor(.white)
            
            // Active user indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                Text("\(city.memberCount) people active")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // Typing indicator view
    @ViewBuilder
    private var typingIndicatorView: some View {
        if !typingUsers.isEmpty {
            HStack(spacing: 4) {
                Text(typingUsers.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(typingUsers.count == 1 ? "is typing..." : "are typing...")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Animated dots
                TypingIndicator()
                    .frame(width: 24, height: 8)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
        }
    }
    
    // Chat messages section
    private var chatMessages: some View {
        ScrollViewReader { scrollView in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(chatManager.messages) { message in
                        cityChatMessageRow(for: message, scrollView: scrollView)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .onChange(of: chatManager.messages.count) { _ in
                scrollToBottom(scrollView: scrollView)
            }
            .onTapGesture {
                isInputFocused = false
                showEmojiPicker = false
            }
        }
    }
    
    // Message row function to reduce complexity
    private func cityChatMessageRow(for message: ChatMessage, scrollView: ScrollViewProxy) -> some View {
        CityChatMessageRow(message: message, onReact: { messageId in
            selectedMessageForReaction = messageId
            showEmojiPicker = true
        })
        .id(message.id)
        .contextMenu {
            Button(action: {
                // Copy message
                UIPasteboard.general.string = message.text
            }) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            
            Button(action: {
                selectedMessageForReaction = message.id
                showEmojiPicker = true
            }) {
                Label("React", systemImage: "face.smiling")
            }
            
            if message.displayName == chatManager.userDisplayName {
                Button(action: {
                    // Delete message (would be implemented in production)
                }) {
                    Label("Delete", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // Scroll to bottom helper
    private func scrollToBottom(scrollView: ScrollViewProxy) {
        if let lastMessage = chatManager.messages.last {
            withAnimation {
                scrollView.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    // Day divider
    private var dayDivider: some View {
        HStack {
            Spacer()
            Text("Today")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    // Message input area
    private var messageInputArea: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack(alignment: .bottom) {
                messageTextField
                sendButton
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.black)
        }
    }
    
    // Message text field
    private var messageTextField: some View {
        ZStack(alignment: .leading) {
            if messageText.isEmpty {
                Text("Type a message...")
                    .foregroundColor(.gray)
                    .padding(.leading, 6)
                    .padding(.top, 8)
            }
            
            TextField("", text: $messageText, axis: .vertical)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .padding(10)
                .foregroundColor(.white)
                .onChange(of: messageText) { newValue in
                    handleMessageTextChange(newValue)
                }
        }
        .padding(4)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
    }
    
    // Handle message text change
    private func handleMessageTextChange(_ newValue: String) {
        // Simulate typing indicator
        if !isTyping && !newValue.isEmpty {
            isTyping = true
            simulateTypingIndicator()
        } else if newValue.isEmpty {
            isTyping = false
        }
    }
    
    // Send button
    private var sendButton: some View {
        let isEmptyMessage = messageText.isEmpty
        
        return Button(action: {
            sendMessage()
        }) {
            Circle()
                .fill(isEmptyMessage ? Color.gray.opacity(0.3) : Color.pink)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                )
        }
        .disabled(isEmptyMessage)
        .padding(.horizontal, 4)
        .scaleEffect(isEmptyMessage ? 0.9 : 1.0)
        .animation(.spring(response: 0.3), value: isEmptyMessage)
    }
    
    // Emoji picker overlay
    @ViewBuilder
    private var emojiPickerOverlay: some View {
        if showEmojiPicker {
            VStack {
                Spacer()
                
                // Emoji selector
                HStack(spacing: 20) {
                    ForEach(["❤️", "👍", "😂", "😮", "🔥", "👏"], id: \.self) { emoji in
                        Button(action: {
                            handleEmojiSelection(emoji)
                        }) {
                            Text(emoji)
                                .font(.system(size: 30))
                        }
                        .buttonStyle(EmojiButtonStyle())
                    }
                }
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(20)
                .shadow(radius: 10)
                .padding()
            }
            .background(Color.black.opacity(0.3).edgesIgnoringSafeArea(.all))
            .onTapGesture {
                showEmojiPicker = false
            }
        }
    }
    
    // Handle emoji selection
    private func handleEmojiSelection(_ emoji: String) {
        if let messageId = selectedMessageForReaction {
            addReaction(emoji: emoji, to: messageId)
        }
        showEmojiPicker = false
    }
    
    // Handle appear
    private func handleAppear() {
        chatManager.joinCityChat(city: city)
        
        // Scroll to bottom initially
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // This would use the scrollView parameter in a real implementation
        }
        
        // Listen for keyboard events
        setupKeyboardObservers()
    }
    
    // Setup keyboard observers
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            keyboardHeight = 0
        }
    }
    
    // Send message
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        chatManager.sendMessage(text: messageText, to: city.id)
        messageText = ""
        isInputFocused = false
        isTyping = false
    }
    
    private func simulateTypingIndicator() {
        // This would communicate with the server in production
        // Here we just simulate it locally
    }
    
    private func simulateRandomUserTyping() {
        let usernames = ["DancingPhoenix", "NeonTiger", "CosmicButterfly", "GlitterDragon"]
        
        // Random chance to show typing indicator
        if Int.random(in: 0...10) > 7 {
            if typingUsers.isEmpty {
                typingUsers.append(usernames.randomElement()!)
                
                // Auto-dismiss after a short time
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 2...5)) {
                    typingUsers.removeAll()
                }
            }
        }
    }
    
    private func addReaction(emoji: String, to messageId: String) {
        // In production, this would update the database
        print("Added reaction \(emoji) to message \(messageId)")
    }
}

// Typing indicator animation
struct TypingIndicator: View {
    @State private var firstCircleOffset: CGFloat = 0
    @State private var secondCircleOffset: CGFloat = 0
    @State private var thirdCircleOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(Color.gray)
                .frame(width: 5, height: 5)
                .offset(y: firstCircleOffset)
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 0.5).repeatForever()) {
                        firstCircleOffset = -5
                    }
                }
            
            Circle()
                .fill(Color.gray)
                .frame(width: 5, height: 5)
                .offset(y: secondCircleOffset)
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 0.5).delay(0.2).repeatForever()) {
                        secondCircleOffset = -5
                    }
                }
            
            Circle()
                .fill(Color.gray)
                .frame(width: 5, height: 5)
                .offset(y: thirdCircleOffset)
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 0.5).delay(0.4).repeatForever()) {
                        thirdCircleOffset = -5
                    }
                }
        }
    }
}

// Enhanced message row
struct CityChatMessageRow: View {
    let message: ChatMessage
    var onReact: (String) -> Void
    
    @ObservedObject private var chatManager = ChatManager.shared
    @State private var showActions = false
    
    // Mock reactions for demo
    @State private var reactions: [String: Int] = [:]
    
    var isCurrentUser: Bool {
        return message.displayName == chatManager.userDisplayName
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if message.isSystemMessage {
                // System message (centered)
                HStack {
                    Spacer()
                    
                    VStack(spacing: 2) {
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
                        
                        Text(chatManager.formatMessageTimestamp(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
            } else if isCurrentUser {
                // Current user's message (right-aligned)
                HStack {
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack {
                            // Message actions button
                            if showActions {
                                Button(action: {
                                    onReact(message.id)
                                }) {
                                    Image(systemName: "face.smiling")
                                        .font(.system(size: 14))
                                        .padding(8)
                                        .background(Color.black.opacity(0.3))
                                        .clipShape(Circle())
                                }
                            }
                            
                            Text(message.text)
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.pink, Color.purple.opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(16)
                                .onTapGesture {
                                    withAnimation {
                                        showActions.toggle()
                                    }
                                }
                        }
                        
                        // Timestamp
                        Text(chatManager.formatMessageTimestamp(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        // Reactions (if any)
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
                }
            } else {
                // Other user's message (left-aligned)
                HStack(alignment: .top, spacing: 8) {
                    // Avatar indicator
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [Color.purple, Color.blue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 36, height: 36)
                        
                        Text(String(message.displayName.prefix(1)))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(message.displayName)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        HStack {
                            Text(message.text)
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(16)
                                .onTapGesture {
                                    withAnimation {
                                        showActions.toggle()
                                    }
                                }
                            
                            // Message actions button
                            if showActions {
                                Button(action: {
                                    onReact(message.id)
                                }) {
                                    Image(systemName: "face.smiling")
                                        .font(.system(size: 14))
                                        .padding(8)
                                        .background(Color.black.opacity(0.3))
                                        .clipShape(Circle())
                                }
                            }
                        }
                        
                        Text(chatManager.formatMessageTimestamp(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        // Reactions (if any)
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
                    
                    Spacer()
                }
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
}

// Custom emoji button style
struct EmojiButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.3 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
} 