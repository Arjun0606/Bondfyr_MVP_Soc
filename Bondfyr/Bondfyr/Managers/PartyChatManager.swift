import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import Combine
import UIKit

class PartyChatManager: ObservableObject {
    static let shared = PartyChatManager()
    
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var currentParty: Afterparty?
    @Published var canPost: Bool = false
    @Published var viewerCount: Int = 0
    @Published var replyingTo: ChatMessage?
    @Published var isUploadingImage: Bool = false
    
    // Anonymous numbering system
    private var guestNumbers: [String: Int] = [:]  // userId -> guestNumber
    private var nextGuestNumber: Int = 1
    
    private let db = Firestore.firestore()
    private var messageListener: ListenerRegistration?
    private var viewerCountListener: ListenerRegistration?
    
    private init() {
        // Schedule periodic cleanup of expired parties
        scheduleAutomaticCleanup()
    }
    
    // MARK: - Party Chat Methods
    
    func startPartyChat(for party: Afterparty) {
        currentParty = party
        resetGuestNumbers()
        
        // Set host permissions
        checkPermissions(for: party)
        
        // Create initial system message
        createInitialSystemMessage(for: party)
        
        // Start listening for messages
        listenForMessages(partyId: party.id)
        
        // Update viewer count
        updateViewerCount(partyId: party.id, increment: 1)
    }
    
    func joinPartyChat(for party: Afterparty) {
        // If joining a different party, clear old data
        let isSameParty = currentParty?.id == party.id
        if !isSameParty {
            messages = []
            resetGuestNumbers()
        }
        
        currentParty = party
        checkPermissions(for: party)
        
        // Start listening for messages
        listenForMessages(partyId: party.id)
        
        // Update viewer count
        updateViewerCount(partyId: party.id, increment: 1)
    }
    
    func leavePartyChat() {
        messageListener?.remove()
        viewerCountListener?.remove()
        
        if let party = currentParty {
            updateViewerCount(partyId: party.id, increment: -1)
        }
        
        // Don't clear ANYTHING - keep all data cached
        // Only clear when party actually ends completely
        canPost = false
    }
    
    func sendMessage(text: String) {
        guard let party = currentParty,
              let userId = Auth.auth().currentUser?.uid,
              canPost else { 
            print("Debug: Can't send message - party: \(currentParty?.title ?? "nil"), userId: \(Auth.auth().currentUser?.uid ?? "nil"), canPost: \(canPost)")
            return 
        }
        
        let displayName = getDisplayName(for: userId, in: party)
        
        let message = ChatMessage(
            text: text,
            userHandle: displayName,
            userId: userId,
            timestamp: Date(),
            partyId: party.id,
            messageType: .text,
            replyToMessageId: replyingTo?.id,
            replyToText: replyingTo?.text,
            replyToUserHandle: replyingTo?.userHandle
        )
        
        print("Debug: Sending message with userId: \(userId), userHandle: \(displayName)")
        
        // Add message to local array immediately for instant UI update
        DispatchQueue.main.async {
            self.messages.append(message)
            self.replyingTo = nil // Clear reply state after sending
        }
        
        // Save to Firebase (this will also trigger the listener, but we already have it locally)
        saveMessage(message)
    }
    
    func sendImage(_ image: UIImage, caption: String = "") {
        guard let party = currentParty,
              let userId = Auth.auth().currentUser?.uid,
              canPost else { return }
        
        isUploadingImage = true
        
        uploadImageToStorage(image) { [weak self] result in
            DispatchQueue.main.async {
                self?.isUploadingImage = false
                
                switch result {
                case .success(let (imageURL, aspectRatio)):
                    self?.sendImageMessage(imageURL: imageURL, aspectRatio: aspectRatio, caption: caption)
                case .failure(let error):
                    print("Error uploading image: \(error)")
                    self?.error = "Failed to upload image"
                }
            }
        }
    }
    
    private func sendImageMessage(imageURL: String, aspectRatio: Double, caption: String) {
        guard let party = currentParty,
              let userId = Auth.auth().currentUser?.uid else { return }
        
        let displayName = getDisplayName(for: userId, in: party)
        
        let message = ChatMessage(
            text: caption,
            userHandle: displayName,
            userId: userId,
            timestamp: Date(),
            partyId: party.id,
            messageType: .image,
            imageURL: imageURL,
            imageAspectRatio: aspectRatio,
            replyToMessageId: replyingTo?.id,
            replyToText: replyingTo?.text,
            replyToUserHandle: replyingTo?.userHandle
        )
        
        // Add message to local array immediately for instant UI update
        DispatchQueue.main.async {
            self.messages.append(message)
            self.replyingTo = nil // Clear reply state
        }
        
        saveMessage(message)
    }
    
    func addReaction(to message: ChatMessage, emoji: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        print("Debug: Adding reaction \(emoji) to message \(message.id)")
        
        // Update local state immediately
        DispatchQueue.main.async {
            if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                var updatedMessage = self.messages[index]
                
                // Initialize reactions if nil
                if updatedMessage.reactions.isEmpty {
                    updatedMessage.reactions = [:]
                }
                
                // Add or remove reaction
                if var userIds = updatedMessage.reactions[emoji] {
                    if userIds.contains(userId) {
                        // Remove reaction
                        userIds.removeAll { $0 == userId }
                        if userIds.isEmpty {
                            updatedMessage.reactions.removeValue(forKey: emoji)
                        } else {
                            updatedMessage.reactions[emoji] = userIds
                        }
                    } else {
                        // Add reaction
                        userIds.append(userId)
                        updatedMessage.reactions[emoji] = userIds
                    }
                } else {
                    // First reaction with this emoji
                    updatedMessage.reactions[emoji] = [userId]
                }
                
                self.messages[index] = updatedMessage
            }
        }
        
        // Save to Firebase using transaction for consistency
        let messageRef = db.collection("party_messages").document(message.id)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let messageDocument: DocumentSnapshot
            do {
                try messageDocument = transaction.getDocument(messageRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard var messageData = messageDocument.data() else {
                print("Debug: Message document not found")
                return nil
            }
            
            // Get current reactions
            var reactions = messageData["reactions"] as? [String: [String]] ?? [:]
            
            // Add or remove reaction
            if var userIds = reactions[emoji] {
                if userIds.contains(userId) {
                    // Remove reaction
                    userIds.removeAll { $0 == userId }
                    if userIds.isEmpty {
                        reactions.removeValue(forKey: emoji)
                    } else {
                        reactions[emoji] = userIds
                    }
                } else {
                    // Add reaction
                    userIds.append(userId)
                    reactions[emoji] = userIds
                }
            } else {
                // First reaction with this emoji
                reactions[emoji] = [userId]
            }
            
            // Update document
            messageData["reactions"] = reactions
            transaction.setData(messageData, forDocument: messageRef)
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("Debug: Error updating reaction: \(error)")
            } else {
                print("Debug: Reaction updated successfully")
            }
        }
    }
    
    func setReplyingTo(_ message: ChatMessage) {
        replyingTo = message
    }
    
    func cancelReply() {
        replyingTo = nil
    }
    
    func endPartyChatForDeletedParty() {
        guard let party = currentParty else { return }
        
        // Send system message first
        let endMessage = ChatMessage(
            text: "📱 Party has been cancelled. Chat is now closed.",
            userHandle: "System",
            userId: "system",
            timestamp: Date(),
            partyId: party.id,
            isSystemMessage: true,
            messageType: .system
        )
        
        saveMessage(endMessage)
        
        // Clean up all party data after a short delay to allow system message to be sent
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            Task {
                await self.cleanupPartyData(partyId: party.id)
            }
        }
        
        // Clear all local data since party is completely ended
        clearAllData()
    }
    
    /// Completely clear all cached data (only when party actually ends)
    private func clearAllData() {
        DispatchQueue.main.async {
            self.messages = []
            self.currentParty = nil
            self.canPost = false
            self.resetGuestNumbers()
        }
    }
    
    private func uploadImageToStorage(_ image: UIImage, completion: @escaping (Result<(String, Double), Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])))
            return
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let imageRef = storageRef.child("party_images/\(UUID().uuidString).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        imageRef.putData(imageData, metadata: metadata) { (metadata, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            imageRef.downloadURL { (url, error) in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let downloadURL = url else {
                    completion(.failure(NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                    return
                }
                
                // Calculate aspect ratio
                let aspectRatio = Double(image.size.width / image.size.height)
                
                completion(.success((downloadURL.absoluteString, aspectRatio)))
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func createInitialSystemMessage(for party: Afterparty) {
        let welcomeMessage = ChatMessage(
            text: "🎉 Welcome to \(party.title)! Only approved guests can post. Everyone else can watch the party live!",
            userHandle: "System",
            userId: "system",
            timestamp: Date(),
            partyId: party.id,
            isSystemMessage: true,
            messageType: .system
        )
        
        saveMessage(welcomeMessage)
    }
    
    private func checkPermissions(for party: Afterparty) {
        guard let userId = Auth.auth().currentUser?.uid else {
            canPost = false
            return
        }
        
        // Host can always post
        if party.userId == userId {
            canPost = true
            return
        }
        
        // Check if user is an approved guest
        let isApprovedGuest = party.guestRequests.contains { request in
            request.userId == userId && request.paymentStatus == .paid
        }
        
        canPost = isApprovedGuest
    }
    
    private func getDisplayName(for userId: String, in party: Afterparty) -> String {
        // Host gets "HOST" badge
        if party.userId == userId {
            return "HOST"
        }
        
        // Assign guest number
        if let existingNumber = guestNumbers[userId] {
            return "Guest #\(existingNumber)"
        } else {
            guestNumbers[userId] = nextGuestNumber
            let guestNumber = nextGuestNumber
            nextGuestNumber += 1
            return "Guest #\(guestNumber)"
        }
    }
    
    private func resetGuestNumbers() {
        guestNumbers = [:]
        nextGuestNumber = 1
    }
    
    private func listenForMessages(partyId: String) {
        // Remove any existing listener first to prevent conflicts
        messageListener?.remove()
        
        messageListener = db.collection("party_messages")
            .whereField("partyId", isEqualTo: partyId)
            .order(by: "timestamp", descending: false)
            .limit(to: 100) // Limit to prevent performance issues
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Debug: Error listening for messages: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("Debug: No messages found")
                    return
                }
                
                print("Debug: Received \(documents.count) messages from Firebase")
                
                let firebaseMessages = documents.compactMap { doc -> ChatMessage? in
                    var data = doc.data()
                    data["id"] = doc.documentID
                    
                    do {
                        var message = try Firestore.Decoder().decode(ChatMessage.self, from: data)
                        
                        // Ensure reactions are properly decoded
                        if let reactions = data["reactions"] as? [String: [String]] {
                            message.reactions = reactions
                        } else {
                            message.reactions = [:]
                        }
                        
                        return message
                    } catch {
                        print("Debug: Error decoding message: \(error)")
                        return nil
                    }
                }
                
                DispatchQueue.main.async {
                    // Smart merge - combine local and Firebase messages, avoiding duplicates
                    var mergedMessages: [ChatMessage] = []
                    var seenIds = Set<String>()
                    
                    // Create a map of local messages for quick lookup
                    let localMessagesMap = Dictionary(uniqueKeysWithValues: (self?.messages ?? []).map { ($0.id, $0) })
                    
                    // Add Firebase messages first (they are the source of truth for content)
                    for fbMessage in firebaseMessages {
                        if !seenIds.contains(fbMessage.id) {
                            var finalMessage = fbMessage
                            
                            // If we have a local version with potentially newer reactions, merge them
                            if let localMessage = localMessagesMap[fbMessage.id] {
                                // Use Firebase content but check if local has more recent reactions
                                // (This handles edge cases where local reactions haven't synced yet)
                                if !localMessage.reactions.isEmpty && localMessage.reactions != fbMessage.reactions {
                                    print("Debug: Merging local reactions for message \(fbMessage.id)")
                                    finalMessage.reactions = localMessage.reactions
                                }
                            }
                            
                            mergedMessages.append(finalMessage)
                            seenIds.insert(finalMessage.id)
                        }
                    }
                    
                    // Add any local messages that aren't in Firebase yet
                    for message in self?.messages ?? [] {
                        if !seenIds.contains(message.id) {
                            mergedMessages.append(message)
                            seenIds.insert(message.id)
                        }
                    }
                    
                    // Sort by timestamp
                    mergedMessages.sort { $0.timestamp < $1.timestamp }
                    
                    self?.messages = mergedMessages
                    print("Debug: Updated messages array with \(mergedMessages.count) messages")
                }
            }
    }
    
    private func saveMessage(_ message: ChatMessage) {
        do {
            try db.collection("party_messages").document(message.id).setData(from: message) { error in
                if let error = error {
                    print("❌ Error saving message: \(error)")
                } else {
                    print("✅ Message saved successfully: \(message.text)")
                }
            }
        } catch {
            print("❌ Error encoding message: \(error)")
        }
    }
    
    private func updateViewerCount(partyId: String, increment: Int) {
        db.collection("party_viewers").document(partyId).updateData([
            "count": FieldValue.increment(Int64(increment))
        ]) { error in
            if error != nil {
                // If document doesn't exist, create it
                self.db.collection("party_viewers").document(partyId).setData([
                    "count": max(increment, 0)
                ])
            }
        }
        
        // Only create listener once
        if viewerCountListener == nil {
            startViewerCountListener(partyId: partyId)
        }
    }
    
    private func startViewerCountListener(partyId: String) {
        viewerCountListener?.remove()
        viewerCountListener = db.collection("party_viewers").document(partyId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let data = snapshot?.data(),
                      let count = data["count"] as? Int else { return }
                
                DispatchQueue.main.async {
                    self?.viewerCount = count
                }
            }
    }
    
    // MARK: - Data Cleanup Functions
    
    /// Comprehensive cleanup of all party-related data when party ends
    private func cleanupPartyData(partyId: String) async {
        print("🧹 Starting cleanup for party: \(partyId)")
        
        // Clean up in parallel for efficiency
        async let messagesCleanup = deleteAllPartyMessages(partyId: partyId)
        async let photosCleanup = deleteAllPartyPhotos(partyId: partyId)
        async let viewersCleanup = deletePartyViewers(partyId: partyId)
        
        // Wait for all cleanup operations to complete
        await messagesCleanup
        await photosCleanup
        await viewersCleanup
        
        print("✅ Cleanup complete for party: \(partyId)")
    }
    
    /// Delete all messages for a specific party
    private func deleteAllPartyMessages(partyId: String) async {
        do {
            let snapshot = try await db.collection("party_messages")
                .whereField("partyId", isEqualTo: partyId)
                .getDocuments()
            
            print("🗑️ Found \(snapshot.documents.count) messages to delete for party: \(partyId)")
            
            // Delete messages in batches to avoid rate limits
            let batch = db.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            
            try await batch.commit()
            print("✅ Deleted all messages for party: \(partyId)")
        } catch {
            print("❌ Error deleting messages for party \(partyId): \(error)")
        }
    }
    
    /// Delete all photos uploaded for a specific party
    private func deleteAllPartyPhotos(partyId: String) async {
        do {
            // First, get all messages with photos for this party
            let snapshot = try await db.collection("party_messages")
                .whereField("partyId", isEqualTo: partyId)
                .whereField("messageType", isEqualTo: "image")
                .getDocuments()
            
            print("🖼️ Found \(snapshot.documents.count) photos to delete for party: \(partyId)")
            
            let storage = Storage.storage()
            
            // Delete each photo from Firebase Storage
            for document in snapshot.documents {
                let data = document.data()
                if let imageURL = data["imageURL"] as? String,
                   let url = URL(string: imageURL) {
                    
                    // Extract the path from the URL
                    let path = url.pathComponents.dropFirst().joined(separator: "/")
                    let imageRef = storage.reference().child(path)
                    
                    do {
                        try await imageRef.delete()
                        print("🗑️ Deleted photo: \(path)")
                    } catch {
                        print("❌ Error deleting photo \(path): \(error)")
                    }
                }
            }
            
            print("✅ Deleted all photos for party: \(partyId)")
        } catch {
            print("❌ Error fetching party photos for deletion: \(error)")
        }
    }
    
    /// Delete party viewers collection
    private func deletePartyViewers(partyId: String) async {
        do {
            let snapshot = try await db.collection("party_viewers")
                .whereField("partyId", isEqualTo: partyId)
                .getDocuments()
            
            print("👥 Found \(snapshot.documents.count) viewer records to delete for party: \(partyId)")
            
            let batch = db.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            
            try await batch.commit()
            print("✅ Deleted all viewer records for party: \(partyId)")
        } catch {
            print("❌ Error deleting viewer records for party \(partyId): \(error)")
        }
    }
    
    /// Manual cleanup function (if needed for testing or maintenance)
    func manualCleanupParty(partyId: String) async {
        await cleanupPartyData(partyId: partyId)
    }
    
    // MARK: - Automatic Cleanup
    
    /// Schedule automatic cleanup of expired parties
    private func scheduleAutomaticCleanup() {
        // Run cleanup every 6 hours
        Timer.scheduledTimer(withTimeInterval: 21600, repeats: true) { _ in
            Task {
                await self.cleanupExpiredParties()
            }
        }
        
        // Also run cleanup once on app launch after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            Task {
                await self.cleanupExpiredParties()
            }
        }
    }
    
    /// Clean up chat data for parties that ended more than 2 hours ago
    private func cleanupExpiredParties() async {
        print("🧹 Starting automatic cleanup of expired parties...")
        
        do {
            let twoHoursAgo = Date().addingTimeInterval(-7200) // 2 hours ago
            
            // Find all parties that ended more than 2 hours ago
            let expiredSnapshot = try await db.collection("afterparties")
                .whereField("endTime", isLessThan: Timestamp(date: twoHoursAgo))
                .getDocuments()
            
            print("🗑️ Found \(expiredSnapshot.documents.count) expired parties to clean up")
            
            // Clean up each expired party
            for document in expiredSnapshot.documents {
                let partyId = document.documentID
                await cleanupPartyData(partyId: partyId)
            }
            
            print("✅ Automatic cleanup completed")
        } catch {
            print("❌ Error during automatic cleanup: \(error)")
        }
    }
} 