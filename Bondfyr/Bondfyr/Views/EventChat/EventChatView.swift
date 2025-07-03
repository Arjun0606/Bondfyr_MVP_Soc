import SwiftUI

struct EventChatView: View {
    let event: Event
    
    @ObservedObject private var chatManager = ChatManager.shared
    @State private var messageText = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var isTyping: Bool = false
    @State private var typingUsers: [String] = []
    @State private var showEmojiPicker = false
    @State private var selectedMessageForReaction: String?
    @FocusState private var isInputFocused: Bool
    @State private var timeRemaining: TimeInterval = 0
    @State private var formattedTimeRemaining: String = ""
    @State private var typingTimer: Timer? = nil
    
    // Timers for updating UI
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    let countdownTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect() // Update every minute
    
    var body: some View {
        ZStack {
            // Background
            backgroundGradient
            
            VStack(spacing: 0) {
                if let error = chatManager.error {
                    // Show access error
                    accessDeniedView(message: error)
                } else {
                    chatHeader
                    chatMessages
                    messageInputArea
                }
            }
            
            emojiPickerOverlay
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    Image(systemName: "music.note.house.fill")
                        .foregroundColor(.pink)
                    Text("\(event.name) Chat")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear(perform: handleAppear)
        .onDisappear {
            chatManager.leaveEventChat()
            chatManager.disableTestMode()
        }
        .onReceive(timer) { _ in
            simulateRandomUserTyping()
        }
        .onReceive(countdownTimer) { _ in
            if let checkInTime = CheckInManager.shared.getCheckInTime(eventId: event.id.uuidString) {
                let expirationTime = checkInTime.addingTimeInterval(7 * 60 * 60) // 7 hours
                updateRemainingTime(expirationTime: expirationTime)
            }
        }
    }
    
    // Background gradient
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.black,
                Color(red: 0.2, green: 0.08, blue: 0.3)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // Chat header with event info
    private var chatHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Event Chat")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                
                if !formattedTimeRemaining.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("Expires in \(formattedTimeRemaining)")
                            .font(.caption)
                    }
                    .foregroundColor(timeRemaining < 3600 ? .red : .gray) // Turn red when less than 1 hour left
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(timeRemaining < 3600 ? Color.red.opacity(0.2) : Color.gray.opacity(0.2))
                    .cornerRadius(10)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                        
                        // Mock user count
                        Text("\(Int.random(in: 12...50)) chatting")
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
                .background(Color.gray.opacity(0.3))
        }
    }
    
    // Chat messages
    private var chatMessages: some View {
        ScrollViewReader { scrollView in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(chatManager.messages) { message in
                        messageRow(for: message, scrollView: scrollView)
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
    
    // Message row
    private func messageRow(for message: ChatMessage, scrollView: ScrollViewProxy) -> some View {
        MessageRow(message: message, onReact: { messageId in
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
    
    // Message input area
    private var messageInputArea: some View {
        VStack(spacing: 0) {
            // Typing indicator
            if !typingUsers.isEmpty {
                HStack {
                    Text("\(typingUsers.first ?? "Someone") is typing...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    Spacer()
                }
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack(alignment: .bottom) {
                // Message text field
                messageTextField
                
                // Send button
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
                Text("Message")
                    .foregroundColor(.gray)
                    .padding(.leading, 4)
            }
            
            TextField("", text: $messageText, onCommit: sendMessage)
                .foregroundColor(.white)
                .focused($isInputFocused)
                .onChange(of: messageText) { newValue in
                    // Set isTyping to true when user starts typing and false after 2 seconds of no typing
                    if !isTyping && !newValue.isEmpty {
                        isTyping = true
                        // In production, this would send a typing indicator to Firestore
                    }
                    
                    // Cancel any previous delay and set a new one
                    resetTypingTimer()
                }
        }
        .padding(10)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
    }
    
    // Send button
    private var sendButton: some View {
        Button(action: sendMessage) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .pink)
        }
        .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    
    // Emoji picker overlay
    private var emojiPickerOverlay: some View {
        Group {
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
    }
    
    // Handle emoji selection
    private func handleEmojiSelection(_ emoji: String) {
        if let messageId = selectedMessageForReaction {
            addReaction(emoji: emoji, to: messageId)
        }
        showEmojiPicker = false
    }
    
    // Add reaction to message
    private func addReaction(emoji: String, to messageId: String) {
        // This would store the reaction in Firestore in production
        
    }
    
    // Handle appear
    private func handleAppear() {
        chatManager.joinEventChat(event: event)
        
        // Setup countdown timer
        if let checkInTime = CheckInManager.shared.getCheckInTime(eventId: event.id.uuidString) {
            let expirationTime = checkInTime.addingTimeInterval(7 * 60 * 60) // 7 hours
            updateRemainingTime(expirationTime: expirationTime)
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
        
        let eventId = event.id.uuidString
        chatManager.sendEventMessage(text: messageText, to: eventId)
        messageText = ""
        isInputFocused = false
        isTyping = false
    }
    
    // Reset typing timer
    private func resetTypingTimer() {
        // Cancel the previous timer if it exists
        typingTimer?.invalidate()
        
        // Create a new timer that will stop the typing indicator after 2 seconds
        typingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { timer in
            DispatchQueue.main.async {
                self.isTyping = false
                // In a real implementation, this would update the typing indicator in Firestore
            }
        }
    }
    
    // Simulate random user typing
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
    
    // Access denied view
    private func accessDeniedView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 50))
                .foregroundColor(.red.opacity(0.7))
                .padding(.bottom, 10)
            
            Text("Access Restricted")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal, 30)
            
            Spacer()
            
            NavigationLink(destination: EventCheckInView(event: event)) {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                    Text("Go to Check-In")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.pink)
                .cornerRadius(8)
            }
            .padding(.top, 20)
        }
        .padding(.top, 50)
        .padding(.horizontal)
    }
    
    // Update the remaining time
    private func updateRemainingTime(expirationTime: Date) {
        timeRemaining = expirationTime.timeIntervalSince(Date())
        
        if timeRemaining <= 0 {
            formattedTimeRemaining = "Expired"
            return
        }
        
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        
        if hours > 0 {
            formattedTimeRemaining = "\(hours)h \(minutes)m"
        } else {
            formattedTimeRemaining = "\(minutes)m"
        }
    }
}

// Preview
struct EventChatView_Previews: PreviewProvider {
    static var previews: some View {
        EventChatView(event: sampleEvents[0])
            .preferredColorScheme(.dark)
    }
} 