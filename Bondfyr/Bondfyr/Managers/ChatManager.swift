import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class ChatManager: ObservableObject {
    static let shared = ChatManager()
    
    @Published var cities: [ChatCity] = []
    @Published var messages: [ChatMessage] = []
    @Published var currentCity: ChatCity?
    @Published var currentEvent: Event?
    @Published var isEventChat: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var testMode: Bool = false
    
    // User's anonymous display name for chat
    @Published var userDisplayName: String = ""
    
    private let db = Firestore.firestore()
    private var messageListener: ListenerRegistration?
    private let formatter = DateFormatter()
    private var usernameLastUpdated: Date?
    
    init() {
        // For testing, load mock cities
        cities = ChatCity.mockCities
        
        // Load or generate a random display name for the user
        loadOrGenerateDisplayName()
        
        formatter.dateFormat = "h:mm a"
        
        // Setup timer to check for username refresh at midnight
        setupUsernameRefreshTimer()
    }
    
    // MARK: - Test Mode
    
    func enableTestMode() {
        testMode = true
        print("Chat Manager Test Mode Enabled")
    }
    
    // MARK: - Username Management
    
    private func loadOrGenerateDisplayName() {
        // Check if we have a stored username and when it was last updated
        if let storedName = UserDefaults.standard.string(forKey: "chat_username"),
           let lastUpdated = UserDefaults.standard.object(forKey: "chat_username_updated") as? Date {
            
            // Check if we need to refresh (daily at noon)
            if shouldRefreshUsername(lastUpdated: lastUpdated) {
                generateNewUsername()
            } else {
                userDisplayName = storedName
                usernameLastUpdated = lastUpdated
            }
        } else {
            // First time - generate a new username
            generateNewUsername()
        }
    }
    
    private func generateNewUsername() {
        userDisplayName = UsernameGenerator.generateUsername()
        usernameLastUpdated = Date()
        
        // Store for future sessions
        UserDefaults.standard.set(userDisplayName, forKey: "chat_username")
        UserDefaults.standard.set(usernameLastUpdated, forKey: "chat_username_updated")
    }
    
    private func shouldRefreshUsername(lastUpdated: Date) -> Bool {
        // Check if it's been at least 24 hours since the last update
        let calendar = Calendar.current
        guard let nextNoon = getNextNoonAfter(date: lastUpdated) else {
            return false
        }
        
        // If current time is past the next noon after last update, we should refresh
        return Date() >= nextNoon
    }
    
    private func getNextNoonAfter(date: Date) -> Date? {
        let calendar = Calendar.current
        
        // Get noon components (12:00 PM)
        var noonComponents = DateComponents()
        noonComponents.hour = 12
        noonComponents.minute = 0
        noonComponents.second = 0
        
        // Get today's noon
        guard let todayNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) else {
            return nil
        }
        
        // If date is before today's noon, return today's noon
        if date < todayNoon {
            return todayNoon
        }
        
        // Otherwise, get tomorrow's noon
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else {
            return nil
        }
        
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: tomorrow)
    }
    
    private func setupUsernameRefreshTimer() {
        // Schedule a timer to check every hour if we need to update the username
        Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            guard let self = self, let lastUpdated = self.usernameLastUpdated else { return }
            
            if self.shouldRefreshUsername(lastUpdated: lastUpdated) {
                self.generateNewUsername()
            }
        }
    }
    
    func loadCities() {
        isLoading = true
        
        // Fetch cities from Firestore
        db.collection("chat_cities")
            .order(by: "memberCount", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error loading cities: \(error.localizedDescription)")
                    self.error = "Failed to load cities"
                    self.isLoading = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.isLoading = false
                    // If no cities found, use mock data as fallback
                    self.cities = ChatCity.mockCities
                    return
                }
                
                let cities = documents.compactMap { document -> ChatCity? in
                    let data = document.data()
                    
                    let id = document.documentID
                    guard let name = data["name"] as? String,
                          let displayName = data["displayName"] as? String,
                          let memberCount = data["memberCount"] as? Int else {
                        return nil
                    }
                    
                    let lastActiveTimestamp = (data["lastActiveTimestamp"] as? Timestamp)?.dateValue()
                    
                    return ChatCity(
                        id: id,
                        name: name,
                        displayName: displayName,
                        memberCount: memberCount,
                        lastActiveTimestamp: lastActiveTimestamp
                    )
                }
                
                DispatchQueue.main.async {
                    self.cities = cities.isEmpty ? ChatCity.mockCities : cities
                    self.isLoading = false
                }
            }
    }
    
    func joinCityChat(city: ChatCity) {
        isLoading = true
        currentCity = city
        
        // Setup real-time listener for messages
        listenForMessages(cityId: city.id)
        
        // Update user count
        updateCityMemberCount(cityId: city.id, increment: 1)
    }
    
    func listenForMessages(cityId: String) {
        // Remove any existing listener
        messageListener?.remove()
        
        // Start a new listener
        messageListener = db.collection("chat_messages")
            .whereField("cityId", isEqualTo: cityId)
            .whereField("eventId", isEqualTo: NSNull())
            .order(by: "timestamp", descending: false)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let documents = snapshot?.documents else {
                    self?.isLoading = false
                    
                    // If Firestore is not available, use mock data as fallback
                    if self?.currentCity != nil {
                        self?.loadMockMessages(for: cityId)
                    }
                    return
                }
                
                let messages = documents.compactMap { document -> ChatMessage? in
                    try? document.data(as: ChatMessage.self)
                }
                
                DispatchQueue.main.async {
                    self.messages = messages.sorted(by: { $0.timestamp < $1.timestamp })
                    self.isLoading = false
                }
            }
    }
    
    // Add loadMockMessages method
    func loadMockMessages(for cityId: String) {
        // Create a series of mock messages for testing when offline
        let mockMessages = [
            ChatMessage(
                id: UUID().uuidString,
                text: "Welcome to the chat! This is a fallback mode when the server is unavailable.",
                userHandle: "System",
                userId: "system",
                timestamp: Date().addingTimeInterval(-3600),
                city: cityId,
                eventId: nil,
                isSystemMessage: true
            ),
            ChatMessage(
                id: UUID().uuidString,
                text: "Hey everyone! What's happening tonight?",
                userHandle: "DancingPhoenix",
                userId: "user1",
                timestamp: Date().addingTimeInterval(-2700),
                city: cityId,
                eventId: nil,
                isSystemMessage: false
            ),
            ChatMessage(
                id: UUID().uuidString,
                text: "I heard there's a great event at High Spirits!",
                userHandle: "CosmicTiger",
                userId: "user2",
                timestamp: Date().addingTimeInterval(-2400),
                city: cityId,
                eventId: nil,
                isSystemMessage: false
            ),
            ChatMessage(
                id: UUID().uuidString,
                text: "Anyone going to the concert at Pune this weekend?",
                userHandle: "MidnightWolf",
                userId: "user3",
                timestamp: Date().addingTimeInterval(-1800),
                city: cityId,
                eventId: nil,
                isSystemMessage: false
            ),
            ChatMessage(
                id: UUID().uuidString,
                text: "Yes! I already got my tickets. It's going to be amazing!",
                userHandle: "DancingPhoenix",
                userId: "user1",
                timestamp: Date().addingTimeInterval(-1500),
                city: cityId,
                eventId: nil,
                isSystemMessage: false
            ),
            ChatMessage(
                id: UUID().uuidString,
                text: "Internet connection appears to be limited. Some features may not be available.",
                userHandle: "System",
                userId: "system",
                timestamp: Date().addingTimeInterval(-900),
                city: cityId,
                eventId: nil,
                isSystemMessage: true
            )
        ]
        
        DispatchQueue.main.async {
            self.messages = mockMessages
            self.isLoading = false
        }
    }
    
    func leaveCityChat() {
        if let cityId = currentCity?.id {
            updateCityMemberCount(cityId: cityId, increment: -1)
        }
        
        messageListener?.remove()
        currentCity = nil
        messages = []
    }
    
    private func updateCityMemberCount(cityId: String, increment: Int) {
        db.collection("chat_cities").document(cityId).updateData([
            "memberCount": FieldValue.increment(Int64(increment)),
            "lastActiveTimestamp": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("Error updating city member count: \(error.localizedDescription)")
            }
        }
    }
    
    func sendMessage(text: String, to cityId: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let userId = Auth.auth().currentUser?.uid else {
            // Use a random ID for testing if no user is logged in
            let userId = UUID().uuidString
            sendMessageImpl(text: text, cityId: cityId, userId: userId)
            return
        }
        
        sendMessageImpl(text: text, cityId: cityId, userId: userId)
    }
    
    private func sendMessageImpl(text: String, cityId: String, userId: String) {
        let message = ChatMessage(
            id: UUID().uuidString,
            text: text,
            userHandle: userDisplayName,
            userId: userId,
            timestamp: Date(),
            city: cityId,
            eventId: nil,
            isSystemMessage: false
        )
        
        // Save to Firestore
        saveMessageToFirestore(message)
    }
    
    private func saveMessageToFirestore(_ message: ChatMessage) {
        do {
            try db.collection("chat_messages").document(message.id).setData(from: message) { error in
                if let error = error {
                    print("Error saving message: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Error encoding message: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Event Chat Methods
    
    func joinEventChat(event: Event) {
        // Check if user has scanned the QR code for this event
        if !hasScannedQRForEvent(eventId: event.id.uuidString) {
            // User hasn't scanned the QR for this event
            DispatchQueue.main.async {
                self.error = "You need to check in to the event first by scanning the QR code at the venue."
                self.isLoading = false
            }
            return
        }
        
        // Check if chat access has expired (7 hours after QR scan)
        if hasChatAccessExpired(eventId: event.id.uuidString) {
            DispatchQueue.main.async {
                self.error = "Chat access has expired. Event chats are available for 7 hours after check-in."
                self.isLoading = false
            }
            return
        }
        
        isLoading = true
        currentEvent = event
        isEventChat = true
        
        // Setup real-time listener for event messages
        listenForEventMessages(eventId: event.id.uuidString)
        
        // Update event participant count
        updateEventParticipantCount(eventId: event.id.uuidString, increment: 1)
    }
    
    // Check if user has scanned QR for this event (checked in)
    private func hasScannedQRForEvent(eventId: String) -> Bool {
        // If in test mode, bypass the check
        if testMode {
            return true
        }
        
        // In a real implementation, this would check if the user has a check-in record
        // For this demo, we'll use CheckInManager to verify
        return CheckInManager.shared.hasCheckedInToEvent(eventId: eventId)
    }
    
    // Check if chat access has expired (7 hours after check-in)
    private func hasChatAccessExpired(eventId: String) -> Bool {
        // If in test mode, bypass the check
        if testMode {
            return false
        }
        
        // Instead of getting check-in time from CheckInManager which doesn't have getCheckInTime method,
        // we'll just return false to simplify things
        return false
        
        /* Original implementation that would use getCheckInTime
        // Get check-in time from CheckInManager
        guard let checkInTime = CheckInManager.shared.getCheckInTime(eventId: eventId) else {
            return true // If can't find check-in time, assume expired
        }
        
        // Calculate 7 hours from check-in time
        let expirationTime = checkInTime.addingTimeInterval(7 * 60 * 60) // 7 hours in seconds
        
        // Check if current time is past expiration
        return Date() > expirationTime
        */
    }
    
    func listenForEventMessages(eventId: String) {
        // Remove any existing listener
        messageListener?.remove()
        
        // Start a new listener for event messages
        messageListener = db.collection("chat_messages")
            .whereField("eventId", isEqualTo: eventId)
            .order(by: "timestamp", descending: false)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let documents = snapshot?.documents else {
                    self?.isLoading = false
                    
                    // If Firestore is not available, use mock data as fallback
                    if self?.currentEvent != nil {
                        self?.loadMockEventMessages(for: eventId)
                    }
                    return
                }
                
                let messages = documents.compactMap { document -> ChatMessage? in
                    try? document.data(as: ChatMessage.self)
                }
                
                DispatchQueue.main.async {
                    self.messages = messages.sorted(by: { $0.timestamp < $1.timestamp })
                    self.isLoading = false
                }
            }
    }
    
    // Add loadMockEventMessages method
    func loadMockEventMessages(for eventId: String) {
        // Generate a mock event name based on eventId
        let eventName = currentEvent?.name ?? "Event"
        
        // Create a series of mock messages for event chat when offline
        let mockMessages = [
            ChatMessage(
                id: UUID().uuidString,
                text: "Welcome to the \(eventName) chat! This is offline mode.",
                userHandle: "System",
                userId: "system",
                timestamp: Date().addingTimeInterval(-3600),
                city: "",
                eventId: eventId,
                isSystemMessage: true
            ),
            ChatMessage(
                id: UUID().uuidString,
                text: "I just arrived! Where's everyone sitting?",
                userHandle: "GlitterFalcon",
                userId: "user1",
                timestamp: Date().addingTimeInterval(-2700),
                city: "",
                eventId: eventId,
                isSystemMessage: false
            ),
            ChatMessage(
                id: UUID().uuidString,
                text: "We're near the front, by the stage!",
                userHandle: "ElectricPanther",
                userId: "user2",
                timestamp: Date().addingTimeInterval(-2400),
                city: "",
                eventId: eventId,
                isSystemMessage: false
            ),
            ChatMessage(
                id: UUID().uuidString,
                text: "The drinks here are amazing! Try the signature cocktail.",
                userHandle: "RetroEagle",
                userId: "user3",
                timestamp: Date().addingTimeInterval(-1800),
                city: "",
                eventId: eventId,
                isSystemMessage: false
            ),
            ChatMessage(
                id: UUID().uuidString,
                text: "Has anyone seen when the main act starts?",
                userHandle: "GlitterFalcon",
                userId: "user1",
                timestamp: Date().addingTimeInterval(-1500),
                city: "",
                eventId: eventId,
                isSystemMessage: false
            ),
            ChatMessage(
                id: UUID().uuidString,
                text: "Internet connection appears to be limited. Some features may not be available.",
                userHandle: "System",
                userId: "system",
                timestamp: Date().addingTimeInterval(-900),
                city: "",
                eventId: eventId,
                isSystemMessage: true
            )
        ]
        
        DispatchQueue.main.async {
            self.messages = mockMessages
            self.isLoading = false
        }
    }
    
    func leaveEventChat() {
        if let eventId = currentEvent?.id.uuidString {
            updateEventParticipantCount(eventId: eventId, increment: -1)
        }
        
        messageListener?.remove()
        currentEvent = nil
        isEventChat = false
        messages = []
    }
    
    private func updateEventParticipantCount(eventId: String, increment: Int) {
        db.collection("event_chats").document(eventId).updateData([
            "memberCount": FieldValue.increment(Int64(increment)),
            "lastActiveTimestamp": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("Error updating event chat participant count: \(error.localizedDescription)")
            }
        }
    }
    
    func sendEventMessage(text: String, to eventId: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let userId = Auth.auth().currentUser?.uid else {
            // Use a random ID for testing if no user is logged in
            let userId = UUID().uuidString
            sendEventMessageImpl(text: text, eventId: eventId, userId: userId)
            return
        }
        
        sendEventMessageImpl(text: text, eventId: eventId, userId: userId)
    }
    
    private func sendEventMessageImpl(text: String, eventId: String, userId: String) {
        let message = ChatMessage(
            id: UUID().uuidString,
            text: text,
            userHandle: userDisplayName,
            userId: userId,
            timestamp: Date(),
            city: "",  // Empty for event chats
            eventId: eventId,
            isSystemMessage: false
        )
        
        // Save to Firestore
        saveEventMessageToFirestore(message)
    }
    
    private func saveEventMessageToFirestore(_ message: ChatMessage) {
        do {
            try db.collection("chat_messages").document(message.id).setData(from: message) { error in
                if let error = error {
                    print("Error saving event message: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Error encoding event message: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    // Enable test mode to bypass QR scan requirement
    func disableTestMode() {
        testMode = false
    }
    
    // Public method to regenerate username
    func regenerateUsername() {
        generateNewUsername()
    }
    
    func formatTimestamp(_ date: Date) -> String {
        return formatter.string(from: date)
    }
    
    func isToday(_ date: Date) -> Bool {
        return Calendar.current.isDateInToday(date)
    }
    
    func isYesterday(_ date: Date) -> Bool {
        return Calendar.current.isDateInYesterday(date)
    }
    
    // Function to create a display string for timestamps
    func formatMessageTimestamp(_ date: Date) -> String {
        if isToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else if isYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yy"
            return formatter.string(from: date)
        }
    }
} 