import Foundation
import UserNotifications
import FirebaseAuth
import FirebaseFirestore

// MARK: - Fixed Notification Manager
@MainActor
class FixedNotificationManager: ObservableObject {
    static let shared = FixedNotificationManager()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let db = Firestore.firestore()
    
    private init() {
        setupNotificationCategories()
    }
    
    // MARK: - Permission Management
    func requestPermissions() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            print("🔔 FIXED: Notification permissions granted: \(granted)")
            return granted
        } catch {
            print("🔴 FIXED: Notification permission error: \(error)")
            return false
        }
    }
    
    private func checkPermissions() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        let isAuthorized = settings.authorizationStatus == .authorized
        print("🔔 FIXED: Checking permissions - authorized: \(isAuthorized)")
        return isAuthorized
    }
    
    // MARK: - Host Notifications (ONLY for hosts)
    func notifyHostOfNewGuestRequest(
        partyId: String,
        partyTitle: String,
        guestName: String,
        hostUserId: String
    ) async {
        print("🔔 FIXED: notifyHostOfNewGuestRequest called")
        print("🔔 FIXED: Target host: \(hostUserId)")
        print("🔔 FIXED: Guest name: \(guestName)")
        
        // Send notification - removed blocking logic
        print("🟢 FIXED: Sending host notification for new guest request")
        
        // Check permissions first
        guard await checkPermissions() else {
            print("🔴 FIXED: No notification permissions")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "🔔 New Guest Request"
        content.body = "\(guestName) wants to join \(partyTitle). Tap to review!"
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "type": "host_guest_request",
            "partyId": partyId,
            "partyTitle": partyTitle,
            "guestName": guestName,
            "targetUserId": hostUserId
        ]
        
        let request = UNNotificationRequest(
            identifier: "host_guest_request_\(partyId)_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
            print("🟢 FIXED: Host notification scheduled successfully")
        } catch {
            print("🔴 FIXED: Failed to schedule host notification: \(error)")
        }
    }
    
    // MARK: - Guest Notifications (ONLY for guests)
    func notifyGuestOfApproval(
        partyId: String,
        partyTitle: String,
        hostName: String,
        guestUserId: String,
        amount: Double
    ) async {
        print("🔔 FIXED: notifyGuestOfApproval called")
        print("🔔 FIXED: Target guest: \(guestUserId)")
        print("🔔 FIXED: Host name: \(hostName)")
        print("🔔 FIXED: Amount: \(amount)")
        
        // Send notification - removed blocking logic
        print("🟢 FIXED: Sending guest notification for approval")
        
        // Check permissions first
        guard await checkPermissions() else {
            print("🔴 FIXED: No notification permissions")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "🎉 Request Approved!"
        content.body = "You're approved for \(partyTitle)! Complete payment ($\(Int(amount))) to secure your spot."
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "type": "guest_approved",
            "partyId": partyId,
            "partyTitle": partyTitle,
            "hostName": hostName,
            "amount": amount,
            "targetUserId": guestUserId,
            "action": "show_payment" // NEW: Trigger payment flow
        ]
        
        let request = UNNotificationRequest(
            identifier: "guest_approved_\(partyId)_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
            print("🟢 FIXED: Guest approval notification scheduled successfully")
            
            // Send follow-up payment reminder after 2 seconds
            await sendPaymentReminder(
                partyId: partyId,
                partyTitle: partyTitle,
                guestUserId: guestUserId,
                amount: amount
            )
        } catch {
            print("🔴 FIXED: Failed to schedule guest notification: \(error)")
        }
    }
    
    private func sendPaymentReminder(
        partyId: String,
        partyTitle: String,
        guestUserId: String,
        amount: Double
    ) async {
        print("🔔 FIXED: Sending payment reminder")
        
        let content = UNMutableNotificationContent()
        content.title = "💳 Payment Required"
        content.body = "Don't forget to complete your payment for \(partyTitle) - $\(Int(amount))"
        content.sound = .default
        
        content.userInfo = [
            "type": "payment_reminder",
            "partyId": partyId,
            "partyTitle": partyTitle,
            "targetUserId": guestUserId
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "payment_reminder_\(partyId)_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            print("🟢 FIXED: Payment reminder scheduled")
        } catch {
            print("🔴 FIXED: Failed to schedule payment reminder: \(error)")
        }
    }
    
    // MARK: - Payment Confirmation
    func notifyGuestOfPaymentSuccess(
        partyId: String,
        partyTitle: String,
        guestUserId: String
    ) async {
        print("🔔 FIXED: notifyGuestOfPaymentSuccess called")
        print("🔔 FIXED: Target guest: \(guestUserId)")
        print("🔔 FIXED: Current user: \(Auth.auth().currentUser?.uid ?? "none")")
        
        // FIXED LOGIC: Only show GUEST notifications to the actual GUEST
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId == guestUserId else {
            print("🚨 FIXED: BLOCKED guest notification - current user is not the guest")
            print("🚨 FIXED: This prevents hosts from seeing guest notifications")
            return
        }
        
        guard await checkPermissions() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "✅ Payment Confirmed!"
        content.body = "You're all set for \(partyTitle)! Party details will be revealed soon."
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "type": "payment_success",
            "partyId": partyId,
            "partyTitle": partyTitle,
            "targetUserId": guestUserId
        ]
        
        let request = UNNotificationRequest(
            identifier: "payment_success_\(partyId)_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
            print("🟢 FIXED: Guest payment success notification scheduled successfully")
        } catch {
            print("🔴 FIXED: Failed to schedule guest payment success notification: \(error)")
        }
    }
    
    func notifyHostOfPaymentReceived(
        partyId: String,
        partyTitle: String,
        guestName: String,
        hostUserId: String,
        amount: String
    ) async {
        print("🔔 FIXED: notifyHostOfPaymentReceived called")
        print("🔔 FIXED: Target host: \(hostUserId)")
        print("🔔 FIXED: Current user: \(Auth.auth().currentUser?.uid ?? "none")")
        
        // FIXED LOGIC: Only show HOST notifications to the actual HOST
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId == hostUserId else {
            print("🚨 FIXED: BLOCKED host notification - current user is not the host")
            print("🚨 FIXED: This prevents guests from seeing host notifications")
            return
        }
        
        guard await checkPermissions() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "💰 Payment Received!"
        content.body = "\(guestName) paid \(amount) for \(partyTitle). Check your earnings!"
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "type": "payment_received",
            "partyId": partyId,
            "partyTitle": partyTitle,
            "guestName": guestName,
            "amount": amount,
            "targetUserId": hostUserId
        ]
        
        let request = UNNotificationRequest(
            identifier: "payment_received_\(partyId)_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
            print("🟢 FIXED: Host payment notification scheduled successfully")
        } catch {
            print("🔴 FIXED: Failed to schedule host payment notification: \(error)")
        }
    }
    
    // MARK: - Setup
    private func setupNotificationCategories() {
        let guestCategory = UNNotificationCategory(
            identifier: "guest_approved",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        let hostCategory = UNNotificationCategory(
            identifier: "host_guest_request",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([guestCategory, hostCategory])
    }
    
    // MARK: - Testing (Safe)
    func testNotifications() async {
        print("🧪 FIXED: Testing notification system")
        
        guard await requestPermissions() else {
            print("🔴 FIXED: No permissions for testing")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "🧪 Test Notification"
        content.body = "Fixed notification system is working!"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "test_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
            print("🟢 FIXED: Test notification sent")
        } catch {
            print("🔴 FIXED: Test notification failed: \(error)")
        }
    }
    
    // MARK: - Clear All Notifications
    func clearAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        print("🧹 FIXED: Cleared all notifications")
    }
} 