import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Real-Time Party Manager
// This handles instant updates for party data using Firebase listeners

class RealTimePartyManager: ObservableObject {
    static let shared = RealTimePartyManager()
    
    @Published var parties: [String: Afterparty] = [:]
    @Published var userPartyStatuses: [String: PartyGuestStatus] = [:]
    @Published var connectionStatus: ConnectionStatus = .connected
    
    private var listeners: [String: ListenerRegistration] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let db = Firestore.firestore()
    
    private init() {
        setupConnectionMonitoring()
        // Start periodic cleanup of ended parties
        startPeriodicCleanup()
    }
    
    deinit {
        removeAllListeners()
        cleanupTimer?.invalidate()
    }
    
    // MARK: - Periodic Cleanup
    private var cleanupTimer: Timer?
    
    private func startPeriodicCleanup() {
        // Check for ended parties every 5 minutes
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.cleanupEndedParties()
        }
    }
    
    private func cleanupEndedParties() {
        let now = Date()
        var partiesToRemove: [String] = []
        
        for (partyId, party) in parties {
            if party.endTime < now {
                partiesToRemove.append(partyId)
            }
        }
        
        for partyId in partiesToRemove {
            print("🗑️ CLEANUP: Removing ended party \(partyId)")
            parties.removeValue(forKey: partyId)
            userPartyStatuses.removeValue(forKey: partyId)
            stopListening(to: partyId)
        }
        
        if !partiesToRemove.isEmpty {
            print("🗑️ CLEANUP: Removed \(partiesToRemove.count) ended parties")
        }
    }
    
    // MARK: - Connection Status
    enum ConnectionStatus {
        case connected
        case connecting
        case disconnected
        case error(String)
    }
    
    // MARK: - Party Listening
    func startListening(to partyId: String) {
        // Don't create duplicate listeners
        guard listeners[partyId] == nil else { return }
        
        print("🔄 REALTIME: Starting listener for party \(partyId)")
        
        let listener = db.collection("afterparties")
            .document(partyId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handlePartyUpdate(partyId: partyId, snapshot: snapshot, error: error)
            }
        
        listeners[partyId] = listener
    }
    
    func stopListening(to partyId: String) {
        listeners[partyId]?.remove()
        listeners.removeValue(forKey: partyId)
        parties.removeValue(forKey: partyId)
        userPartyStatuses.removeValue(forKey: partyId)
        
        print("🔄 REALTIME: Stopped listener for party \(partyId)")
    }
    
    func removeAllListeners() {
        for (partyId, listener) in listeners {
            listener.remove()
            print("🔄 REALTIME: Removed listener for party \(partyId)")
        }
        listeners.removeAll()
        parties.removeAll()
        userPartyStatuses.removeAll()
    }
    
    // MARK: - Batch Party Listening
    func startListeningToMultipleParties(_ partyIds: [String]) {
        for partyId in partyIds {
            startListening(to: partyId)
        }
    }
    
    // MARK: - User-Specific Party Monitoring
    func startMonitoringUserParties() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Listen to parties where user is host
        let hostListener = db.collection("afterparties")
            .whereField("userId", isEqualTo: currentUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleUserPartiesUpdate(snapshot: snapshot, error: error, type: .hosted)
            }
        
        listeners["user_hosted"] = hostListener
        
        // Listen to parties where user has requests or is active
        let guestListener = db.collection("afterparties")
            .whereField("activeUsers", arrayContains: currentUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleUserPartiesUpdate(snapshot: snapshot, error: error, type: .attending)
            }
        
        listeners["user_attending"] = guestListener
    }
    
    private enum UserPartyType {
        case hosted
        case attending
    }
    
    // MARK: - Event Handlers
    private func handlePartyUpdate(partyId: String, snapshot: DocumentSnapshot?, error: Error?) {
        if let error = error {
            print("🔴 REALTIME: Error listening to party \(partyId): \(error)")
            connectionStatus = .error(error.localizedDescription)
            return
        }
        
        guard let snapshot = snapshot,
              snapshot.exists,
              let data = snapshot.data() else {
            print("🔴 REALTIME: Party \(partyId) no longer exists")
            parties.removeValue(forKey: partyId)
            userPartyStatuses.removeValue(forKey: partyId)
            return
        }
        
        do {
            var partyData = data
            partyData["id"] = snapshot.documentID
            
            let party = try Firestore.Decoder().decode(Afterparty.self, from: partyData)
            
            // CRITICAL FIX: Remove ended parties from real-time manager
            if party.endTime < Date() {
                print("🗑️ REALTIME: Party \(partyId) has ended - removing from manager")
                parties.removeValue(forKey: partyId)
                userPartyStatuses.removeValue(forKey: partyId)
                stopListening(to: partyId)
                return
            }
            
            // Update party data
            print("🔄 REALTIME: Party data updated - old requests: \(parties[partyId]?.guestRequests.count ?? 0), new requests: \(party.guestRequests.count)")
            let wasUpdated = parties[partyId] != nil
            parties[partyId] = party
            
            // Update user status for this party
            updateUserStatus(for: partyId, party: party)
            
            print("🔄 REALTIME: Party \(partyId) updated - activeUsers: \(party.activeUsers.count), requests: \(party.guestRequests.count)")
            
            if wasUpdated {
                // Send notification about the update
                NotificationCenter.default.post(
                    name: Notification.Name("PartyDataUpdated"),
                    object: nil,
                    userInfo: ["partyId": partyId, "party": party]
                )
            }
            
            connectionStatus = .connected
            
        } catch {
            print("🔴 REALTIME: Error decoding party \(partyId): \(error)")
            connectionStatus = .error("Failed to decode party data")
        }
    }
    
    private func handleUserPartiesUpdate(snapshot: QuerySnapshot?, error: Error?, type: UserPartyType) {
        if let error = error {
            print("🔴 REALTIME: Error in user parties listener (\(type)): \(error)")
            return
        }
        
        guard let snapshot = snapshot else { return }
        
        for change in snapshot.documentChanges {
            let partyId = change.document.documentID
            
            switch change.type {
            case .added, .modified:
                startListening(to: partyId)
                
            case .removed:
                stopListening(to: partyId)
            }
        }
    }
    
    private func updateUserStatus(for partyId: String, party: Afterparty) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let guestState = PartyGuestState(partyId: partyId, userId: currentUserId)
        let newStatus = guestState.calculateStatus(from: party, userId: currentUserId)
        
        let oldStatus = userPartyStatuses[partyId]
        userPartyStatuses[partyId] = newStatus
        
        // Send notification if status changed
        if oldStatus != newStatus {
            print("🔄 REALTIME: User status changed for party \(partyId): \(oldStatus?.rawValue ?? "nil") → \(newStatus.rawValue)")
            
            NotificationCenter.default.post(
                name: Notification.Name("UserPartyStatusChanged"),
                object: nil,
                userInfo: [
                    "partyId": partyId,
                    "oldStatus": oldStatus?.rawValue ?? "",
                    "newStatus": newStatus.rawValue,
                    "party": party
                ]
            )
            
            // Trigger haptic feedback for important status changes
            triggerHapticFeedback(for: newStatus)
        }
    }
    
    // MARK: - Connection Monitoring
    private func setupConnectionMonitoring() {
        // Monitor Firestore connection status
        let settings = FirestoreSettings()
        db.settings = settings
        
        // Use Firestore enableNetwork/disableNetwork for connection monitoring
        // This is a simplified approach - in production you might want more sophisticated monitoring
        connectionStatus = .connected
        
        // You can also monitor network connectivity using Network framework if needed
        // For now, we'll rely on Firestore's built-in error handling
    }
    
    // MARK: - Utility Methods
    func getParty(_ partyId: String) -> Afterparty? {
        return parties[partyId]
    }
    
    func getUserStatus(for partyId: String) -> PartyGuestStatus? {
        return userPartyStatuses[partyId]
    }
    
    func isListening(to partyId: String) -> Bool {
        return listeners[partyId] != nil
    }
    
    private func triggerHapticFeedback(for status: PartyGuestStatus) {
        let impact: UIImpactFeedbackGenerator
        
        switch status {
        case .approved, .going:
            impact = UIImpactFeedbackGenerator(style: .medium)
        case .denied:
            impact = UIImpactFeedbackGenerator(style: .heavy)
        default:
            impact = UIImpactFeedbackGenerator(style: .light)
        }
        
        impact.impactOccurred()
    }
}

// MARK: - Smart Notification Manager Extension
extension RealTimePartyManager {
    func enableSmartNotifications() {
        // Listen for status changes and send intelligent notifications
        NotificationCenter.default.publisher(for: Notification.Name("UserPartyStatusChanged"))
            .sink { [weak self] notification in
                self?.handleStatusChangeNotification(notification)
            }
            .store(in: &cancellables)
    }
    
    private func handleStatusChangeNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let partyId = userInfo["partyId"] as? String,
              let newStatusRaw = userInfo["newStatus"] as? String,
              let newStatus = PartyGuestStatus(rawValue: newStatusRaw),
              let party = userInfo["party"] as? Afterparty else { return }
        
        // Send appropriate notification based on status change
        switch newStatus {
        case .approved:
            NotificationManager.shared.scheduleLocalNotification(
                for: .requestApproved(partyId: partyId, partyTitle: party.title, hostName: party.hostHandle),
                delaySeconds: 0
            )
            
        case .denied:
            NotificationManager.shared.scheduleLocalNotification(
                for: .requestDenied(partyId: partyId, partyTitle: party.title, hostName: party.hostHandle),
                delaySeconds: 0
            )
            
        case .going:
            NotificationManager.shared.scheduleLocalNotification(
                for: .partyStartingSoon(partyId: partyId, partyTitle: party.title, minutesUntil: 0),
                delaySeconds: 0
            )
            
        default:
            break
        }
    }
}

// MARK: - Enhanced Firestore Real-time Support
extension RealTimePartyManager {
    func enableEnhancedRealtimeUpdates() {
        // Use Firestore real-time listeners for ultra-fast updates
        // Firestore provides excellent real-time capabilities without needing Realtime Database
        
        // Listen for rapid party status changes using Firestore
        enableSmartNotifications()
        
        print("🔄 REALTIME: Enhanced Firestore real-time updates enabled")
    }
    
    // Additional real-time features can be added here using Firestore
    func enableInstantStatusUpdates() {
        // This could listen to a specific subcollection for instant updates
        // For example: afterparties/{partyId}/instant_updates
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // You can implement instant updates using Firestore subcollections if needed
        print("🔄 REALTIME: Instant status updates enabled for user \(currentUserId)")
    }
} 