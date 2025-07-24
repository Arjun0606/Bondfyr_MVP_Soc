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
        
        // Call Firebase Cloud Function
        do {
            let functionsUrl = "https://us-central1-bondfyr-da123.cloudfunctions.net/sendPushNotification"
            
            var request = URLRequest(url: URL(string: functionsUrl)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: notificationData)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("🟢 FCM: Notification sent successfully to \(userId)")
            } else {
                print("🔴 FCM: Failed to send notification to \(userId)")
            }
            
        } catch {
            print("🔴 FCM: Error sending notification: \(error)")
        }
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
    
    /// Notify GUEST when request is approved
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
            "amount": amount,
            "action": "complete_payment"
        ]
        
        await sendNotificationToUser(
            userId: guestUserId,
            title: "🎉 Request Approved!",
            body: "You're approved for \(partyTitle)! Complete payment ($\(Int(amount))) to secure your spot.",
            data: data
        )
    }
    
    /// Notify GUEST when payment is verified  
    func notifyGuestOfPaymentVerification(
        guestUserId: String,
        partyId: String,
        partyTitle: String,
        approved: Bool
    ) async {
        print("🔔 FCM: Notifying GUEST \(guestUserId) of payment verification: \(approved)")
        
        let data: [String: Any] = [
            "type": approved ? "payment_approved" : "payment_rejected",
            "partyId": partyId,
            "partyTitle": partyTitle,
            "approved": approved
        ]
        
        if approved {
            await sendNotificationToUser(
                userId: guestUserId,
                title: "✅ You're Going!",
                body: "Your payment for \(partyTitle) has been verified. See you at the party! 🎉",
                data: data
            )
        } else {
            await sendNotificationToUser(
                userId: guestUserId,
                title: "⚠️ Payment Issue",
                body: "There was an issue with your payment proof for \(partyTitle). Please resubmit.",
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
        
        // Handle notification tap
        if let type = userInfo["type"] as? String,
           let partyId = userInfo["partyId"] as? String {
            
            switch type {
            case "guest_request", "payment_proof":
                // Navigate to host dashboard
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToHostDashboard"),
                    object: nil,
                    userInfo: ["partyId": partyId]
                )
                
            case "request_approved", "payment_approved", "payment_rejected":
                // Navigate to party details
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToPartyDetails"),
                    object: nil,
                    userInfo: ["partyId": partyId]
                )
                
            default:
                break
            }
        }
        
        completionHandler()
    }
} 