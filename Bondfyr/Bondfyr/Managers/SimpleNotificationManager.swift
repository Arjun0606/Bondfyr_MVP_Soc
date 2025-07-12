import Foundation
import UserNotifications
import FirebaseAuth

/// SIMPLE NOTIFICATION MANAGER - Actually works correctly!
@MainActor
class SimpleNotificationManager: ObservableObject {
    static let shared = SimpleNotificationManager()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private init() {}
    
    // MARK: - Setup
    func requestPermissions() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            print("🔔 SIMPLE: Notification permissions granted: \(granted)")
            return granted
        } catch {
            print("🔴 SIMPLE: Notification permission error: \(error)")
            return false
        }
    }
    
    // MARK: - Host Notifications
    /// When a guest submits a request → notify HOST
    func sendHostNotification_NewGuestRequest(guestName: String, partyTitle: String) async {
        print("🟢 SIMPLE: Sending HOST notification - New guest request from \(guestName)")
        
        let content = UNMutableNotificationContent()
        content.title = "🔔 New Guest Request"
        content.body = "\(guestName) wants to join \(partyTitle). Tap to review!"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "host_new_guest_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
            print("✅ SIMPLE: Host notification sent successfully")
        } catch {
            print("🔴 SIMPLE: Failed to send host notification: \(error)")
        }
    }
    
    // MARK: - Guest Notifications
    /// When host approves a guest → notify GUEST
    func sendGuestNotification_RequestApproved(partyTitle: String, amount: Double) async {
        print("🟢 SIMPLE: Sending GUEST notification - Request approved for \(partyTitle)")
        
        let content = UNMutableNotificationContent()
        content.title = "🎉 Request Approved!"
        content.body = "You're approved for \(partyTitle)! Complete payment ($\(Int(amount))) to secure your spot."
        content.sound = .default
        
        // CRITICAL: Add payment action
        content.userInfo = ["action": "show_payment"]
        
        let request = UNNotificationRequest(
            identifier: "guest_approved_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
            print("✅ SIMPLE: Guest approval notification sent successfully")
            
            // Post local notification to trigger payment flow
            NotificationCenter.default.post(
                name: Notification.Name("GuestApproved"),
                object: nil,
                userInfo: ["action": "show_payment"]
            )
        } catch {
            print("🔴 SIMPLE: Failed to send guest notification: \(error)")
        }
    }
    
    /// Payment reminder for guest
    func sendGuestNotification_PaymentReminder(partyTitle: String, amount: Double) async {
        print("🟢 SIMPLE: Sending GUEST notification - Payment reminder")
        
        let content = UNMutableNotificationContent()
        content.title = "💳 Payment Required"
        content.body = "Don't forget to complete your payment for \(partyTitle) - $\(Int(amount))"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "payment_reminder_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            print("✅ SIMPLE: Payment reminder sent successfully")
        } catch {
            print("🔴 SIMPLE: Failed to send payment reminder: \(error)")
        }
    }
    
    // MARK: - Clear All
    func clearAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        print("🧹 SIMPLE: Cleared all notifications")
    }
} 