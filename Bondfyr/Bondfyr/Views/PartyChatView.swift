import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

struct PartyChatView: View {
    let afterparty: Afterparty
    @StateObject private var partyChatManager = PartyChatManager.shared
    @State private var messageText = ""
    @State private var showingImagePicker = false
    @State private var imagePickerSource: ImagePicker.Source = .camera
    @State private var replyingTo: ChatMessage? = nil
    @State private var showingQuickReactions = false
    @State private var reactionTargetMessage: ChatMessage? = nil
    @State private var reactionPosition: CGPoint = .zero
    @State private var showingViewOnlyAlert = false
    
    // Quick reaction emojis
    private let quickEmojis = ["🔥", "❤️", "🎉"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(partyChatManager.messages) { message in
                            MessageBubbleView(
                                message: message,
                                canPost: partyChatManager.canPost,
                                onReply: { msg in
                                    replyingTo = msg
                                },
                                onQuickReaction: { msg, position in
                                    reactionTargetMessage = msg
                                    reactionPosition = position
                                    showingQuickReactions = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .onChange(of: partyChatManager.messages.count) { _ in
                    if let lastMessage = partyChatManager.messages.last {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Reply preview (compact)
            if let replyMsg = replyingTo {
                CompactReplyPreview(message: replyMsg) {
                    replyingTo = nil
                }
            }
            
            // Message input
            messageInputView
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            partyChatManager.joinPartyChat(for: afterparty)
            
            // Show FOMO alert if user can only view (not post)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if !partyChatManager.canPost {
                    showingViewOnlyAlert = true
                }
            }
        }
        .onDisappear {
            partyChatManager.leavePartyChat()
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(source: imagePickerSource) { image in
                if let image = image {
                    partyChatManager.sendImage(image)
                }
            }
        }
        .alert("Party Chat - View Only", isPresented: $showingViewOnlyAlert) {
            Button("Got It") { }
        } message: {
            Text("🔒 You can only view this party chat because you're not approved yet. Request to join the party to start chatting with everyone!")
        }
        .overlay(
            // Quick reaction popup
            QuickReactionPopup(
                isShowing: $showingQuickReactions,
                position: reactionPosition,
                emojis: quickEmojis
            ) { emoji in
                if let message = reactionTargetMessage {
                    partyChatManager.addReaction(to: message, emoji: emoji)
                }
                showingQuickReactions = false
                reactionTargetMessage = nil
            }
        )
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .center, spacing: 2) {
                Text(afterparty.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(afterparty.locationName)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Viewer count
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("\(partyChatManager.viewerCount)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black)
    }
    
    private var messageInputView: some View {
        HStack(spacing: 12) {
            // Camera button
            Button(action: {
                if partyChatManager.canPost {
                    imagePickerSource = .camera
                    showingImagePicker = true
                }
            }) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 20))
                    .foregroundColor(partyChatManager.canPost ? .pink : .gray)
            }
            .disabled(!partyChatManager.canPost)
            
            // Photo library button
            Button(action: {
                if partyChatManager.canPost {
                    imagePickerSource = .photoLibrary
                    showingImagePicker = true
                }
            }) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 20))
                    .foregroundColor(partyChatManager.canPost ? .pink : .gray)
            }
            .disabled(!partyChatManager.canPost)
            
            // Message input
            TextField("Message...", text: $messageText)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .disabled(!partyChatManager.canPost)
            
            // Send button
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.pink)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !partyChatManager.canPost)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black)
    }
    
    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Set reply info BEFORE sending the message
        partyChatManager.replyingTo = replyingTo
        partyChatManager.sendMessage(text: trimmedText)
        
        // Clear reply state after sending
        replyingTo = nil
        messageText = ""
    }
}

// MARK: - Message Bubble with Swipe and Long Press
struct MessageBubbleView: View {
    let message: ChatMessage
    let canPost: Bool
    let onReply: (ChatMessage) -> Void
    let onQuickReaction: (ChatMessage, CGPoint) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var showingReplyIndicator = false
    @GestureState private var isLongPressing = false
    
    var body: some View {
        HStack {
            if !message.isSystemMessage {
                if message.userId == Auth.auth().currentUser?.uid {
                    Spacer()
                    messageContent
                        .offset(x: dragOffset.width)
                        .gesture(swipeGesture)
                        .gesture(longPressGesture)
                } else {
                    messageContent
                        .offset(x: dragOffset.width)
                        .gesture(swipeGesture)
                        .gesture(longPressGesture)
                    Spacer()
                }
            } else {
                // System message - centered
                HStack {
                    Spacer()
                    messageContent
                    Spacer()
                }
            }
        }
        .overlay(
            // Reply indicator
            HStack {
                if showingReplyIndicator {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.pink)
                        .offset(x: -40)
                }
                Spacer()
            }
        )
    }
    
    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Message bubble
            VStack(alignment: .leading, spacing: 8) {
                // Reply context (if this is a reply)
                if let replyToText = message.replyToText,
                   let replyToHandle = message.replyToUserHandle {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(replyToHandle)
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(replyToText)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5).opacity(0.3))
                    .cornerRadius(8)
                }
                
                // Message content
                if message.messageType == .image, let imageURL = message.imageURL {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 200)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 200, height: 200)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            )
                    }
                } else {
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(backgroundForMessage)
            .cornerRadius(16)
            
            // Reactions underneath the bubble - always aligned to the left edge of the bubble
            if !message.reactions.isEmpty {
                ReactionView(reactions: message.reactions)
                    .padding(.leading, 4)
                    .padding(.top, 2)
            }
            
            // Timestamp underneath the bubble
            Text(formatTime(message.timestamp))
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(.leading, 4)
        }
    }
    
    private var backgroundForMessage: some View {
        Group {
            if message.isSystemMessage {
                Color.purple.opacity(0.3)
            } else if message.userId == Auth.auth().currentUser?.uid {
                LinearGradient(
                    gradient: Gradient(colors: [Color.pink.opacity(0.8), Color.purple.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color(.systemGray6).opacity(0.2)
            }
        }
    }
    
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow swipe left for replies
                if value.translation.width < 0 && abs(value.translation.width) > abs(value.translation.height) {
                    dragOffset = CGSize(width: max(value.translation.width, -50), height: 0)
                    showingReplyIndicator = dragOffset.width < -20
                }
            }
            .onEnded { value in
                if dragOffset.width < -30 && canPost {
                    onReply(message)
                }
                withAnimation(.spring()) {
                    dragOffset = .zero
                    showingReplyIndicator = false
                }
            }
    }
    
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                // Calculate position relative to the screen center
                let screenWidth = UIScreen.main.bounds.width
                let screenHeight = UIScreen.main.bounds.height
                let position = CGPoint(x: screenWidth / 2, y: screenHeight / 2)
                onQuickReaction(message, position)
            }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Compact Reply Preview
struct CompactReplyPreview: View {
    let message: ChatMessage
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.pink)
                .frame(width: 2, height: 24)
            
            HStack(spacing: 4) {
                Text("Reply to")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Text(message.userHandle)
                    .font(.caption2)
                    .foregroundColor(.pink)
                    .fontWeight(.medium)
                
                Text("•")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Text(message.text)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            Spacer()
            
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }
}

// MARK: - Quick Reaction Popup
struct QuickReactionPopup: View {
    @Binding var isShowing: Bool
    let position: CGPoint
    let emojis: [String]
    let onEmojiTap: (String) -> Void
    
    var body: some View {
        if isShowing {
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isShowing = false
                    }
                
                // Reaction buttons
                HStack(spacing: 20) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button(action: {
                            onEmojiTap(emoji)
                        }) {
                            Text(emoji)
                                .font(.system(size: 32))
                                .frame(width: 60, height: 60)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .scaleEffect(isShowing ? 1.0 : 0.1)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(emojis.firstIndex(of: emoji) ?? 0) * 0.1), value: isShowing)
                    }
                }
                .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
            }
        }
    }
}

// MARK: - Reaction View (Updated)
struct ReactionView: View {
    let reactions: [String: [String]]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(reactions.keys), id: \.self) { emoji in
                let count = reactions[emoji]?.count ?? 0
                if count > 0 {
                    HStack(spacing: 2) {
                        Text(emoji)
                            .font(.caption)
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray6).opacity(0.3))
                    .cornerRadius(10)
                }
            }
        }
    }
}

// MARK: - Preview
struct PartyChatView_Previews: PreviewProvider {
    static var previews: some View {
        PartyChatView(afterparty: Afterparty(
            id: "preview",
            userId: "preview-user",
            hostHandle: "HOST",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            radius: 100,
            startTime: Date(),
            endTime: Date(),
            city: "Preview City",
            locationName: "Preview Location",
            description: "Preview Description",
            address: "Preview Address",
            googleMapsLink: "",
            vibeTag: "chill",
            title: "Preview Party",
            ticketPrice: 10.0,
            maxGuestCount: 50,
            venmoHandle: "@preview"
        ))
    }
} 