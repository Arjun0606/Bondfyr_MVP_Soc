import Foundation
import FirebaseMessaging
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

/// PROPER FCM PUSH NOTIFICATION MANAGER
/// Sends notifications to the RIGHT users, not just the current device
class FCMNotificationManager: NSObject, ObservableObject {
    static let shared = FCMNotificationManager()
    
    private let db = Firestore.firestore()
    private let messaging = Messaging.messaging()
    
    override init() {
        super.init()
        messaging.delegate = self
        requestNotificationPermissions()
        setupAPNs()
    }
    
    // MARK: - Setup
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("🔔 FCM: Notification permission granted: \(granted)")
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    private func setupAPNs() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Token Management
    
    /// Get current user's FCM token and save to Firestore
    func updateUserFCMToken() async {
        guard let currentUser = Auth.auth().currentUser else {
            print("🔴 FCM: No current user to update token")
            return
        }
        
        do {
            let token = try await messaging.token()
            print("🟢 FCM: Got token: \(token)")
            
            // Save token to user's Firestore document
            try await db.collection("users").document(currentUser.uid).updateData([
                "fcmToken": token,
                "tokenUpdatedAt": Timestamp(date: Date()),
                "platform": "ios"
            ])
            
            print("🟢 FCM: Token saved to Firestore for user \(currentUser.uid)")
            
        } catch {
            print("🔴 FCM: Failed to update token: \(error)")
        }
    }
    
    /// Get FCM token for a specific user
    private func getFCMToken(for userId: String) async -> String? {
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            return doc.data()?["fcmToken"] as? String
        } catch {
            print("🔴 FCM: Failed to get token for user \(userId): \(error)")
            return nil
        }
    }
    
    // MARK: - Send Notifications via Cloud Function
    
    /// Send notification to specific user via Firebase Cloud Function
    private func sendNotificationToUser(
        userId: String,
        title: String,
        body: String,
        data: [String: Any] = [:]
    ) async {
        print("🚀 FCM: Sending notification to user \(userId)")
        print("🚀 FCM: Title: \(title)")
        print("🚀 FCM: Body: \(body)")
        
        let notificationData: [String: Any] = [
            "targetUserId": userId,
            "title": title,
            "body": body,
            "data": data,
            "platform": "ios"
        ]
        
        // PRODUCTION MONITORING: Track notification attempts
        await logNotificationAttempt(userId: userId, title: title, type: data["type"] as? String ?? "unknown")
        
        // Use existing Firebase Cloud Function callable methods
        do {
            let functionsUrl = "https://us-central1-bondfyr-da123.cloudfunctions.net/sendPushNotificationHTTP"
            
            var request = URLRequest(url: URL(string: functionsUrl)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: notificationData)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔔 FCM: HTTP Status: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🔔 FCM: Response: \(responseString)")
                }
                
                if httpResponse.statusCode == 200 {
                    print("🟢 FCM: Notification sent successfully to \(userId)")
                    // PRODUCTION MONITORING: Track successful delivery
                    await logNotificationSuccess(userId: userId, title: title, type: notificationData["type"] as? String ?? "unknown")
                } else {
                    print("🔴 FCM: Failed to send notification to \(userId) - Status: \(httpResponse.statusCode)")
                    // PRODUCTION MONITORING: Track delivery failures
                    await logNotificationFailure(userId: userId, title: title, error: "HTTP \(httpResponse.statusCode)", type: notificationData["type"] as? String ?? "unknown")
                }
            }
            
        } catch {
            print("🔴 FCM: Error sending notification: \(error)")
            // PRODUCTION MONITORING: Track network errors
            await logNotificationFailure(userId: userId, title: title, error: error.localizedDescription, type: data["type"] as? String ?? "unknown")
        }
    }
    
    // MARK: - Production Monitoring
    
    /// Log notification attempt for analytics
    private func logNotificationAttempt(userId: String, title: String, type: String) async {
        do {
            let logData: [String: Any] = [
                "userId": userId,
                "title": title,
                "type": type,
                "status": "attempted",
                "timestamp": FieldValue.serverTimestamp(),
                "platform": "ios"
            ]
            
            try await db.collection("notificationAnalytics").addDocument(data: logData)
        } catch {
            print("🔴 FCM: Failed to log notification attempt: \(error)")
        }
    }
    
    /// Log successful notification delivery
    private func logNotificationSuccess(userId: String, title: String, type: String) async {
        do {
            let logData: [String: Any] = [
                "userId": userId,
                "title": title,
                "type": type,
                "status": "delivered",
                "timestamp": FieldValue.serverTimestamp(),
                "platform": "ios"
            ]
            
            try await db.collection("notificationAnalytics").addDocument(data: logData)
        } catch {
            print("🔴 FCM: Failed to log notification success: \(error)")
        }
    }
    
    /// Log failed notification delivery
    private func logNotificationFailure(userId: String, title: String, error: String, type: String) async {
        do {
            let logData: [String: Any] = [
                "userId": userId,
                "title": title,
                "type": type,
                "status": "failed",
                "error": error,
                "timestamp": FieldValue.serverTimestamp(),
                "platform": "ios"
            ]
            
            try await db.collection("notificationAnalytics").addDocument(data: logData)
        } catch {
            print("🔴 FCM: Failed to log notification failure: \(error)")
        }
    }
    
    /// Track notification open/tap for engagement analytics
    func trackNotificationOpened(type: String, partyId: String? = nil) async {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        do {
            let logData: [String: Any] = [
                "userId": currentUser.uid,
                "type": type,
                "action": "opened",
                "partyId": partyId ?? "",
                "timestamp": FieldValue.serverTimestamp(),
                "platform": "ios"
            ]
            
            try await db.collection("notificationEngagement").addDocument(data: logData)
            print("📊 FCM: Tracked notification open - type: \(type)")
        } catch {
            print("🔴 FCM: Failed to track notification open: \(error)")
        }
    }
    
    // MARK: - General Notifications
    
    /// Send a push notification to any user
    func sendPushNotification(
        to userId: String,
        title: String,
        body: String,
        data: [String: Any] = [:]
    ) async {
        await sendNotificationToUser(
            userId: userId,
            title: title,
            body: body,
            data: data
        )
    }
    
    // MARK: - Host Notifications
    
    /// Notify HOST when guest submits a request
    func notifyHostOfGuestRequest(
        hostUserId: String,
        partyId: String,
        partyTitle: String,
        guestName: String
    ) async {
        print("🔔 FCM: Notifying HOST \(hostUserId) of guest request from \(guestName)")
        
        let data: [String: Any] = [
            "type": "guest_request",
            "partyId": partyId,
            "partyTitle": partyTitle,
            "guestName": guestName,
            "action": "open_host_dashboard"
        ]
        
        await sendNotificationToUser(
            userId: hostUserId,
            title: "🔔 New Guest Request",
            body: "\(guestName) wants to join \(partyTitle). Tap to review!",
            data: data
        )
    }
    
    /// Notify HOST when guest submits payment proof  
    func notifyHostOfPaymentProof(
        hostUserId: String,
        partyId: String,
        partyTitle: String,
        guestName: String
    ) async {
        print("🔔 FCM: Notifying HOST \(hostUserId) of payment proof from \(guestName)")
        
        let data: [String: Any] = [
            "type": "payment_proof",
            "partyId": partyId,
            "partyTitle": partyTitle,
            "guestName": guestName,
            "action": "verify_payment"
        ]
        
        await sendNotificationToUser(
            userId: hostUserId,
            title: "💰 Payment Proof Submitted",
            body: "\(guestName) submitted payment proof for \(partyTitle). Tap to verify!",
            data: data
        )
    }
    
    /// Notify HOST when payment is verified
    func notifyHostOfPaymentVerified(
        hostUserId: String,
        partyId: String,
        partyTitle: String,
        guestName: String,
        amount: Double
    ) async {
        print("🔔 FCM: Notifying HOST \(hostUserId) of verified payment")
        
        let data: [String: Any] = [
            "type": "payment_verified",
            "partyId": partyId,
            "partyTitle": partyTitle,
            "guestName": guestName,
            "amount": amount
        ]
        
        await sendNotificationToUser(
            userId: hostUserId,
            title: "✅ Payment Verified",
            body: "\(guestName) is now attending \(partyTitle). You earned $\(Int(amount * 0.8))!",
            data: data
        )
    }
    
    // MARK: - Guest Notifications
    
    /// Send guest approval notification
    func notifyGuestOfApproval(
        guestUserId: String,
        partyId: String,
        partyTitle: String,
        hostName: String,
        amount: Double
    ) async {
        print("🔔 FCM: Notifying GUEST \(guestUserId) of approval")
        
        let data: [String: Any] = [
            "type": "request_approved",
            "partyId": partyId,
            "partyTitle": partyTitle,
            "hostName": hostName,
            "amount": amount
        ]
        
        await sendNotificationToUser(
            userId: guestUserId,
            title: "🎉 You're Going!",
            body: "Your request for \(partyTitle) was approved! Pay $\(String(format: "%.0f", amount)) directly to \(hostName) to secure your spot.",
            data: data
        )
    }
    
    /// Send VIP guest approval notification  
    func notifyGuestOfVIPApproval(
        guestUserId: String,
        partyId: String,
        partyTitle: String,
        hostName: String
    ) async {
        print("🔔 FCM: Notifying GUEST \(guestUserId) of VIP approval")
        
        let data: [String: Any] = [
            "type": "vip_approved",
            "partyId": partyId,
            "partyTitle": partyTitle,
            "hostName": hostName
        ]
        
        await sendNotificationToUser(
            userId: guestUserId,
            title: "👑 VIP Access Approved!",
            body: "You've been approved for VIP access to \(partyTitle)! Contact \(hostName) for payment details.",
            data: data
        )
    }
    
    /// Send payment verification notification to guest
    func notifyGuestOfPaymentVerification(
        guestUserId: String,
        partyId: String,
        partyTitle: String,
        isApproved: Bool
    ) async {
        print("🔔 FCM: Notifying GUEST \(guestUserId) of payment verification")
        
        let data: [String: Any] = [
            "type": isApproved ? "payment_approved" : "payment_rejected",
            "partyId": partyId,
            "partyTitle": partyTitle
        ]
        
        if isApproved {
            await sendNotificationToUser(
                userId: guestUserId,
                title: "✅ Payment Confirmed!",
                body: "Your payment for \(partyTitle) has been confirmed. You're all set for the party!",
                data: data
            )
        } else {
            await sendNotificationToUser(
                userId: guestUserId,
                title: "❌ Payment Issue",
                body: "There was an issue with your payment for \(partyTitle). Please contact the host to resolve.",
                data: data
            )
        }
    }
    
    /// Notify GUEST when request is denied
    func notifyGuestOfDenial(
        guestUserId: String,
        partyId: String,
        partyTitle: String,
        hostName: String
    ) async {
        print("🔔 FCM: Notifying GUEST \(guestUserId) of denial")
        
        let data: [String: Any] = [
            "type": "request_denied",
            "partyId": partyId,
            "partyTitle": partyTitle,
            "hostName": hostName
        ]
        
        await sendNotificationToUser(
            userId: guestUserId,
            title: "Request Update",
            body: "Your request for \(partyTitle) wasn't approved this time. Keep exploring other parties!",
            data: data
        )
    }
    
    // MARK: - Reputation System Notifications
    
    /// Send rating request notification to guests after party ends
    func sendRatingRequestNotification(to userId: String, partyId: String) async {
        print("🔔 FCM: Sending rating request to user \(userId) for party \(partyId)")
        
        let data: [String: Any] = [
            "type": "rating_request",
            "partyId": partyId,
            "action": "rate_party"
        ]
        
        await sendNotificationToUser(
            userId: userId,
            title: "🌟 Rate Your Experience",
            body: "How was the party? Your rating helps the community!",
            data: data
        )
    }
    
    /// Send host verification notification
    func sendHostVerificationNotification(to userId: String) async {
        print("🔔 FCM: Sending host verification to user \(userId)")
        
        let data: [String: Any] = [
            "type": "host_verified",
            "action": "view_profile"
        ]
        
        await sendNotificationToUser(
            userId: userId,
            title: "🏆 Verified Host!",
            body: "Congratulations! You're now a Verified Host on Bondfyr.",
            data: data
        )
    }
    
    /// Send guest verification notification
    func sendGuestVerificationNotification(to userId: String) async {
        print("🔔 FCM: Sending guest verification to user \(userId)")
        
        let data: [String: Any] = [
            "type": "guest_verified",
            "action": "view_profile"
        ]
        
        await sendNotificationToUser(
            userId: userId,
            title: "⭐ Verified Guest!",
            body: "Congratulations! You're now a Verified Guest on Bondfyr.",
            data: data
        )
    }
    
    /// Send achievement notification
    func sendAchievementNotification(to userId: String, message: String) async {
        print("🔔 FCM: Sending achievement notification to user \(userId)")
        
        let data: [String: Any] = [
            "type": "achievement",
            "action": "view_profile"
        ]
        
        await sendNotificationToUser(
            userId: userId,
            title: "🎉 Achievement Unlocked!",
            body: message,
            data: data
        )
    }
}

// MARK: - MessagingDelegate
extension FCMNotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔔 FCM: Received registration token: \(fcmToken ?? "nil")")
        
        // Update token in Firestore when it changes
        Task {
            await updateUserFCMToken()
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate  
extension FCMNotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // PRODUCTION MONITORING: Track notification engagement
        if let type = userInfo["type"] as? String {
            let partyId = userInfo["partyId"] as? String
            Task {
                await trackNotificationOpened(type: type, partyId: partyId)
            }
        }
        
        // Handle notification tap navigation
        if let type = userInfo["type"] as? String,
           let partyId = userInfo["partyId"] as? String {
            
            switch type {
            case "guest_request", "payment_proof", "payment_received":
                // Navigate to host dashboard
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToHostDashboard"),
                    object: nil,
                    userInfo: ["partyId": partyId]
                )
                
            case "request_approved", "payment_approved", "payment_rejected", "guest_payment_confirmed":
                // Navigate to party details  
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToPartyDetails"),
                    object: nil,
                    userInfo: ["partyId": partyId]
                )
                
            case "rating_request":
                // Navigate to party rating view
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToPartyRating"),
                    object: nil,
                    userInfo: ["partyId": partyId]
                )
                
            case "host_verified", "guest_verified", "achievement":
                // Navigate to profile view
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToProfile"),
                    object: nil,
                    userInfo: ["type": type]
                )
                
            case "listing_fee_confirmed":
                // Navigate to party feed to see live party
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToPartyFeed"),
                    object: nil,
                    userInfo: ["type": type]
                )
                
            default:
                print("🔔 FCM: Unknown notification type: \(type)")
                break
            }
        }
        
        completionHandler()
    }
} 