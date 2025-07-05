import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class PartyChatManager: ObservableObject {
    static let shared = PartyChatManager()
    
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var currentParty: Afterparty?
    @Published var canPost: Bool = false
    @Published var viewerCount: Int = 0
    
    // Anonymous numbering system
    private var guestNumbers: [String: Int] = [:]  // userId -> guestNumber
    private var nextGuestNumber: Int = 1
    
    private let db = Firestore.firestore()
    private var messageListener: ListenerRegistration?
    private var viewerCountListener: ListenerRegistration?
    
    init() {}
    
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
        
        currentParty = nil
        messages = []
        canPost = false
        resetGuestNumbers()
    }
    
    func sendMessage(text: String) {
        guard let party = currentParty,
              let userId = Auth.auth().currentUser?.uid,
              canPost else { return }
        
        let displayName = getDisplayName(for: userId, in: party)
        
        let message = ChatMessage(
            text: text,
            userHandle: displayName,
            userId: userId,
            partyId: party.id
        )
        
        saveMessage(message)
    }
    
    func endPartyChatForDeletedParty() {
        guard let party = currentParty else { return }
        
        // Send system message
        let endMessage = ChatMessage(
            text: "📱 Party has been cancelled. Chat is now closed.",
            userHandle: "System",
            userId: "system",
            partyId: party.id,
            isSystemMessage: true
        )
        
        saveMessage(endMessage)
    }
    
    // MARK: - Private Methods
    
    private func createInitialSystemMessage(for party: Afterparty) {
        let welcomeMessage = ChatMessage(
            text: "🎉 Welcome to \(party.title)! Only approved guests can post. Everyone else can watch the party live!",
            userHandle: "System",
            userId: "system",
            partyId: party.id,
            isSystemMessage: true
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
        messageListener?.remove()
        
        messageListener = db.collection("party_messages")
            .whereField("partyId", isEqualTo: partyId)
            .order(by: "timestamp", descending: false)
            .limit(to: 100) // Limit to last 100 messages for better performance
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening to messages: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let messages = documents.compactMap { document -> ChatMessage? in
                    try? document.data(as: ChatMessage.self)
                }
                
                DispatchQueue.main.async {
                    self.messages = messages
                    self.isLoading = false
                }
            }
    }
    
    private func saveMessage(_ message: ChatMessage) {
        do {
            try db.collection("party_messages").document(message.id).setData(from: message)
            print("✅ Message saved successfully: \(message.text)")
        } catch {
            print("❌ Error saving message: \(error)")
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
} 